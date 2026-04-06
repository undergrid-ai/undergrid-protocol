import type { PublicClient, WalletClient, Account, Hash, Hex, Address } from "viem";
import { parseEventLogs } from "viem";
import { getProtocolContracts } from "../contracts";
import { IPFSClient } from "../ipfs/client";
import { JobRegistryAbi } from "../abis/index";
import type { ProtocolAddresses, Job, AgentProfileInput } from "../types";
import { JobState, AgentRole } from "../types";

export interface WorkerConfig {
  addresses: ProtocolAddresses;
  publicClient: PublicClient;
  walletClient: WalletClient & { account: Account };
  ipfs: IPFSClient;
}

/**
 * WorkerAgent — discovers jobs matching capabilities, accepts, executes, and submits results.
 *
 * @example
 * const worker = new WorkerAgent({ addresses, publicClient, walletClient, ipfs });
 * await worker.stake(parseEther("0.1"));
 * const jobs = await worker.discoverOpenJobs();
 */
export class WorkerAgent {
  private readonly contracts: ReturnType<typeof getProtocolContracts>;
  private readonly ipfs: IPFSClient;
  private readonly walletClient: WalletClient & { account: Account };

  constructor(private readonly config: WorkerConfig) {
    this.contracts = getProtocolContracts(
      config.addresses,
      config.publicClient,
      config.walletClient
    );
    this.ipfs = config.ipfs;
    this.walletClient = config.walletClient;
  }

  // -------------------------------------------------------------------------
  // Staking
  // -------------------------------------------------------------------------

  async stake(amount: bigint): Promise<Hash> {
    return this.contracts.stakingVault.write.stake([], {
      value: amount,
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });
  }

  async getStake(address?: Address): Promise<bigint> {
    const addr = address ?? this.walletClient.account.address;
    return this.contracts.stakingVault.read.getStake([addr]);
  }

  // -------------------------------------------------------------------------
  // Registration
  // -------------------------------------------------------------------------

  async registerProfile(input: AgentProfileInput): Promise<Hash> {
    const cidStr = await this.ipfs.uploadJSON(input.capabilities, "capabilities.json");
    const capabilitiesCID = IPFSClient.cidToBytes32(cidStr);

    return this.contracts.agentRegistry.write.registerAgent(
      [
        {
          capabilitiesCID,
          taskTypes: input.taskTypes,
          pricePerJob: input.pricePerJob,
          maxLatencySeconds: BigInt(input.maxLatencySeconds),
          role: input.role,
          active: true,
          registeredAt: 0n,
        },
      ],
      {
        account: this.walletClient.account,
        chain: this.walletClient.chain,
      }
    );
  }

  // -------------------------------------------------------------------------
  // Job discovery
  // -------------------------------------------------------------------------

  /**
   * Returns a list of OPEN jobs by scanning JobCreated events from the given block range.
   * For production use, call the off-chain Discovery API instead.
   */
  async discoverOpenJobs(opts?: {
    fromBlock?: bigint;
    taskType?: string;
    maxResults?: number;
  }): Promise<Array<{ jobId: bigint; job: Job }>> {
    const fromBlock = opts?.fromBlock ?? 0n;
    const maxResults = opts?.maxResults ?? 50;

    const logs = await this.config.publicClient.getLogs({
      address: this.config.addresses.jobRegistry,
      event: JobRegistryAbi.find((x) => x.type === "event" && x.name === "JobCreated") as never,
      fromBlock,
      toBlock: "latest",
    });

    const results: Array<{ jobId: bigint; job: Job }> = [];

    for (const log of logs.slice(-maxResults)) {
      const parsed = parseEventLogs({
        abi: JobRegistryAbi,
        logs: [log],
        eventName: "JobCreated",
      });
      if (parsed.length === 0) continue;

      const jobId = parsed[0].args.jobId;
      const jobRaw = await this.contracts.jobRegistry.read.getJob([jobId]);
      const job = jobRaw as unknown as Job;

      if (job.state === JobState.OPEN) {
        results.push({ jobId, job });
      }
    }

    return results;
  }

  // -------------------------------------------------------------------------
  // Job lifecycle
  // -------------------------------------------------------------------------

  /**
   * Accept an open job, nominating a verifier.
   */
  async acceptJob(jobId: bigint, verifier: Address): Promise<Hash> {
    return this.contracts.jobRegistry.write.acceptJob([jobId, verifier], {
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });
  }

  /**
   * Upload the result to IPFS and submit the CID on-chain.
   */
  async submitResult(jobId: bigint, resultData: unknown): Promise<{ txHash: Hash; resultCID: Hex }> {
    const cidStr = await this.ipfs.uploadJSON(resultData, "result.json");
    const resultCID = IPFSClient.cidToBytes32(cidStr);

    const txHash = await this.contracts.jobRegistry.write.submitResult([jobId, resultCID], {
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });

    return { txHash, resultCID };
  }

  // -------------------------------------------------------------------------
  // Reputation
  // -------------------------------------------------------------------------

  async getScore(address?: Address): Promise<bigint> {
    const addr = address ?? this.walletClient.account.address;
    return this.contracts.reputationSystem.read.getScore([addr]);
  }

  async getStats(address?: Address) {
    const addr = address ?? this.walletClient.account.address;
    return this.contracts.reputationSystem.read.getStats([addr]);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  async getJob(jobId: bigint): Promise<Job> {
    const raw = await this.contracts.jobRegistry.read.getJob([jobId]);
    return raw as unknown as Job;
  }

  /** Download job inputs from IPFS and return parsed JSON. */
  async fetchJobInput<T = unknown>(job: Job): Promise<T> {
    const cid = IPFSClient.bytes32ToCid(job.inputCID);
    return this.ipfs.fetchJSON<T>(cid);
  }

  async fetchJobDescription(job: Job): Promise<string> {
    const cid = IPFSClient.bytes32ToCid(job.descriptionCID);
    return this.ipfs.fetchText(cid);
  }

  async fetchSuccessCriteria(job: Job): Promise<string> {
    const cid = IPFSClient.bytes32ToCid(job.successCriteriaCID);
    return this.ipfs.fetchText(cid);
  }
}
