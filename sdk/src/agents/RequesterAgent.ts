import type { PublicClient, WalletClient, Account, Hash, Hex } from "viem";
import { parseEventLogs } from "viem";
import { getProtocolContracts } from "../contracts";
import { IPFSClient } from "../ipfs/client";
import { JobRegistryAbi } from "../abis/index";
import type {
  ProtocolAddresses,
  JobSpecInput,
  JobSpec,
  Job,
  JobState,
} from "../types";
import { DisputeMechanism } from "../types";

export interface RequesterConfig {
  addresses: ProtocolAddresses;
  publicClient: PublicClient;
  walletClient: WalletClient & { account: Account };
  ipfs: IPFSClient;
}

/**
 * RequesterAgent — creates jobs, monitors progress, cancels if needed.
 *
 * @example
 * const requester = new RequesterAgent({ addresses, publicClient, walletClient, ipfs });
 * const { jobId } = await requester.createJob({ description: "...", inputData: [...], ... });
 */
export class RequesterAgent {
  private readonly contracts: ReturnType<typeof getProtocolContracts>;
  private readonly ipfs: IPFSClient;
  private readonly walletClient: WalletClient & { account: Account };

  constructor(private readonly config: RequesterConfig) {
    this.contracts = getProtocolContracts(
      config.addresses,
      config.publicClient,
      config.walletClient
    );
    this.ipfs = config.ipfs;
    this.walletClient = config.walletClient;
  }

  // -------------------------------------------------------------------------
  // Create
  // -------------------------------------------------------------------------

  /**
   * Upload job inputs to IPFS, then post the job on-chain with payment locked.
   * Returns the job ID and the transaction hash.
   */
  async createJob(input: JobSpecInput): Promise<{ jobId: bigint; txHash: Hash }> {
    // Upload all content to IPFS first
    const [descriptionCIDStr, inputCIDStr, outputSchemaCIDStr, successCriteriaCIDStr] =
      await Promise.all([
        this.ipfs.uploadText(input.description, "description.txt"),
        this.ipfs.uploadJSON(input.inputData, "input.json"),
        this.ipfs.uploadJSON(input.outputSchema, "output-schema.json"),
        this.ipfs.uploadText(input.successCriteria, "criteria.txt"),
      ]);

    const spec: JobSpec = {
      descriptionCID: IPFSClient.cidToBytes32(descriptionCIDStr),
      inputCID: IPFSClient.cidToBytes32(inputCIDStr),
      outputSchemaCID: IPFSClient.cidToBytes32(outputSchemaCIDStr),
      successCriteriaCID: IPFSClient.cidToBytes32(successCriteriaCIDStr),
      payment: input.payment,
      verifierFee: input.verifierFee,
      bidDeadline: BigInt(Math.floor(Date.now() / 1000) + input.bidDeadlineSeconds),
      challengeWindow: BigInt(input.challengeWindowSeconds),
      disputeType: input.disputeType ?? DisputeMechanism.MULTI_AGENT_CONSENSUS,
    };

    return this.createJobFromSpec(spec);
  }

  /**
   * Post a job directly from a pre-built spec (CIDs already computed).
   */
  async createJobFromSpec(spec: JobSpec): Promise<{ jobId: bigint; txHash: Hash }> {
    const txHash = await this.contracts.jobRegistry.write.createJob([spec], {
      value: spec.payment,
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });

    const receipt = await this.config.publicClient.waitForTransactionReceipt({ hash: txHash });

    const logs = parseEventLogs({
      abi: JobRegistryAbi,
      logs: receipt.logs,
      eventName: "JobCreated",
    });

    if (logs.length === 0) throw new Error("JobCreated event not found in receipt");
    const jobId = logs[0].args.jobId;

    return { jobId, txHash };
  }

  // -------------------------------------------------------------------------
  // Cancel
  // -------------------------------------------------------------------------

  async cancelJob(jobId: bigint): Promise<Hash> {
    return this.contracts.jobRegistry.write.cancelJob([jobId], {
      account: this.walletClient.account,
      chain: this.walletClient.chain,
    });
  }

  // -------------------------------------------------------------------------
  // Read
  // -------------------------------------------------------------------------

  async getJob(jobId: bigint): Promise<Job> {
    const raw = await this.contracts.jobRegistry.read.getJob([jobId]);
    return raw as unknown as Job;
  }

  async getJobCount(): Promise<bigint> {
    return this.contracts.jobRegistry.read.jobCount();
  }

  /** Resolve the human-readable description for a job from IPFS. */
  async getJobDescription(job: Job): Promise<string> {
    const cid = IPFSClient.bytes32ToCid(job.descriptionCID);
    return this.ipfs.fetchText(cid);
  }
}
