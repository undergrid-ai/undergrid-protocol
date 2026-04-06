import type { PublicClient, WalletClient, Account, Hash, Hex, Address } from "viem";
import { parseEventLogs } from "viem";
import { getProtocolContracts } from "../contracts";
import { IPFSClient } from "../ipfs/client";
import { JobRegistryAbi } from "../abis/index";
import type { ProtocolAddresses, Job, AgentProfileInput } from "../types";
import { JobState } from "../types";

export interface VerifierConfig {
  addresses: ProtocolAddresses;
  publicClient: PublicClient;
  walletClient: WalletClient & { account: Account };
  ipfs: IPFSClient;
}

export interface VerificationResult {
  passed: boolean;
  score?: number;
  reasoning?: string;
  evidence?: unknown;
}

/**
 * VerifierAgent — picks up submitted jobs, evaluates results against the success
 * criteria, and attests on-chain.
 *
 * @example
 * const verifier = new VerifierAgent({ addresses, publicClient, walletClient, ipfs });
 * const pending = await verifier.getPendingVerifications();
 * for (const { jobId, job } of pending) {
 *   const result = await myEvaluator(job);
 *   await verifier.attestVerification(jobId, result.passed);
 * }
 */
export class VerifierAgent {
  private readonly contracts: ReturnType<typeof getProtocolContracts>;
  private readonly ipfs: IPFSClient;
  private readonly walletClient: WalletClient & { account: Account };

  /** Exposed for advanced use (reading contract state directly). */
  readonly publicClient: PublicClient;

  constructor(readonly config: VerifierConfig) {
    this.contracts = getProtocolContracts(
      config.addresses,
      config.publicClient,
      config.walletClient
    );
    this.ipfs = config.ipfs;
    this.walletClient = config.walletClient;
    this.publicClient = config.publicClient;
  }

  // -------------------------------------------------------------------------
  // Setup
  // -------------------------------------------------------------------------

  async stake(amount: bigint): Promise<Hash> {
    return this.contracts.stakingVault.write.stake([], {
      value: amount,
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });
  }

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
  // Discovery
  // -------------------------------------------------------------------------

  /**
   * Returns jobs in SUBMITTED state where this verifier is assigned.
   * Scans ResultSubmitted events; filters by job.verifier === this address.
   */
  async getPendingVerifications(opts?: {
    fromBlock?: bigint;
    maxResults?: number;
  }): Promise<Array<{ jobId: bigint; job: Job; resultCID: Hex }>> {
    const fromBlock = opts?.fromBlock ?? 0n;
    const maxResults = opts?.maxResults ?? 50;
    const myAddress = this.walletClient.account.address;

    const logs = await this.config.publicClient.getLogs({
      address: this.config.addresses.jobRegistry,
      event: JobRegistryAbi.find(
        (x) => x.type === "event" && x.name === "ResultSubmitted"
      ) as never,
      fromBlock,
      toBlock: "latest",
    });

    const results: Array<{ jobId: bigint; job: Job; resultCID: Hex }> = [];

    for (const log of logs.slice(-maxResults)) {
      const parsed = parseEventLogs({
        abi: JobRegistryAbi,
        logs: [log],
        eventName: "ResultSubmitted",
      });
      if (parsed.length === 0) continue;

      const { jobId, resultCID } = parsed[0].args;
      const jobRaw = await this.contracts.jobRegistry.read.getJob([jobId]);
      const job = jobRaw as unknown as Job;

      if (
        job.state === JobState.SUBMITTED &&
        job.verifier.toLowerCase() === myAddress.toLowerCase()
      ) {
        results.push({ jobId, job, resultCID: resultCID as Hex });
      }
    }

    return results;
  }

  // -------------------------------------------------------------------------
  // Verification
  // -------------------------------------------------------------------------

  /**
   * Attest whether a submitted result passes the success criteria.
   * `success = true` moves the job to VERIFIED; `false` opens a dispute.
   */
  async attestVerification(jobId: bigint, success: boolean): Promise<Hash> {
    return this.contracts.jobRegistry.write.attestVerification([jobId, success], {
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });
  }

  // -------------------------------------------------------------------------
  // Dispute voting
  // -------------------------------------------------------------------------

  async castDisputeVote(jobId: bigint, supportsWorker: boolean): Promise<Hash> {
    return this.contracts.disputeResolver.write.castVote([jobId, supportsWorker], {
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });
  }

  async raiseDispute(jobId: bigint): Promise<Hash> {
    return this.contracts.disputeResolver.write.raiseDispute([jobId], {
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });
  }

  // -------------------------------------------------------------------------
  // Settlement
  // -------------------------------------------------------------------------

  /** Trigger settlement for a verified job after the challenge window. */
  async settleJob(jobId: bigint): Promise<Hash> {
    return this.contracts.jobRegistry.write.settleJob([jobId], {
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });
  }

  // -------------------------------------------------------------------------
  // Data helpers
  // -------------------------------------------------------------------------

  async fetchResult<T = unknown>(resultCID: Hex): Promise<T> {
    const cid = IPFSClient.bytes32ToCid(resultCID);
    return this.ipfs.fetchJSON<T>(cid);
  }

  async fetchJobInput<T = unknown>(job: Job): Promise<T> {
    const cid = IPFSClient.bytes32ToCid(job.inputCID);
    return this.ipfs.fetchJSON<T>(cid);
  }

  async fetchSuccessCriteria(job: Job): Promise<string> {
    const cid = IPFSClient.bytes32ToCid(job.successCriteriaCID);
    return this.ipfs.fetchText(cid);
  }

  async getScore(address?: Address): Promise<bigint> {
    const addr = address ?? this.walletClient.account.address;
    return this.contracts.reputationSystem.read.getScore([addr]);
  }
}
