import type { Address, Hash, Hex } from "viem";

// -------------------------------------------------------------------------
// Enums (mirror Solidity)
// -------------------------------------------------------------------------

export enum JobState {
  OPEN = 0,
  ACCEPTED = 1,
  SUBMITTED = 2,
  VERIFIED = 3,
  SETTLED = 4,
  DISPUTED = 5,
  RESOLVED = 6,
  CANCELLED = 7,
}

export enum DisputeMechanism {
  MULTI_AGENT_CONSENSUS = 0,
  HUMAN_ARBITRATION = 1,
  OPTIMISTIC = 2,
}

export enum AgentRole {
  WORKER = 0,
  VERIFIER = 1,
  BOTH = 2,
}

// -------------------------------------------------------------------------
// On-chain data shapes
// -------------------------------------------------------------------------

export interface Job {
  descriptionCID: Hex; // bytes32 IPFS CID
  inputCID: Hex;
  outputSchemaCID: Hex;
  successCriteriaCID: Hex;
  payment: bigint; // wei
  verifierFee: bigint;
  bidDeadline: bigint; // unix timestamp
  challengeWindow: bigint; // seconds
  requester: Address;
  worker: Address;
  verifier: Address;
  disputeType: DisputeMechanism;
  state: JobState;
  createdAt: bigint;
  acceptedAt: bigint;
  submittedAt: bigint;
}

export interface AgentStats {
  totalJobs: bigint;
  completedJobs: bigint;
  disputesLost: bigint;
  verificationsPassed: bigint;
  verificationsFailed: bigint;
  cumulativeLatencySeconds: bigint;
  lastUpdated: bigint;
}

export interface AgentProfile {
  capabilitiesCID: Hex;
  taskTypes: string[];
  pricePerJob: bigint;
  maxLatencySeconds: bigint;
  role: AgentRole;
  active: boolean;
  registeredAt: bigint;
}

// -------------------------------------------------------------------------
// SDK input types
// -------------------------------------------------------------------------

/** Spec passed to createJob(). IPFS fields are uploaded by RequesterAgent first. */
export interface JobSpec {
  descriptionCID: Hex;
  inputCID: Hex;
  outputSchemaCID: Hex;
  successCriteriaCID: Hex;
  payment: bigint;
  verifierFee: bigint;
  bidDeadline: bigint;
  challengeWindow: bigint;
  disputeType: DisputeMechanism;
}

/** Human-readable job specification before IPFS upload. */
export interface JobSpecInput {
  description: string;
  inputData: unknown; // will be JSON-serialized and uploaded to IPFS
  outputSchema: unknown;
  successCriteria: string;
  payment: bigint;
  verifierFee: bigint;
  bidDeadlineSeconds: number; // seconds from now
  challengeWindowSeconds: number;
  disputeType: DisputeMechanism;
}

export interface AgentProfileInput {
  capabilities: AgentCapabilityManifest;
  taskTypes: string[];
  pricePerJob: bigint;
  maxLatencySeconds: number;
  role: AgentRole;
}

/** Machine-readable capability manifest stored on IPFS. */
export interface AgentCapabilityManifest {
  version: "1.0";
  agentName: string;
  description: string;
  taskTypes: string[];
  supportedInputFormats: string[]; // e.g. ["application/json", "text/plain"]
  supportedOutputFormats: string[];
  pricing: {
    minPriceWei: string;
    currency: "ETH";
  };
  latencyMs: {
    p50: number;
    p95: number;
  };
  tools?: string[];
}

// -------------------------------------------------------------------------
// Protocol configuration
// -------------------------------------------------------------------------

export interface ProtocolAddresses {
  jobRegistry: Address;
  escrow: Address;
  stakingVault: Address;
  agentRegistry: Address;
  reputationSystem: Address;
  disputeResolver: Address;
}

export const BASE_SEPOLIA_ADDRESSES: ProtocolAddresses = {
  // Populated after deployment — update with actual addresses
  jobRegistry: "0x0000000000000000000000000000000000000000",
  escrow: "0x0000000000000000000000000000000000000000",
  stakingVault: "0x0000000000000000000000000000000000000000",
  agentRegistry: "0x0000000000000000000000000000000000000000",
  reputationSystem: "0x0000000000000000000000000000000000000000",
  disputeResolver: "0x0000000000000000000000000000000000000000",
};

// -------------------------------------------------------------------------
// Event types
// -------------------------------------------------------------------------

export interface JobCreatedEvent {
  jobId: bigint;
  requester: Address;
  payment: bigint;
  transactionHash: Hash;
}

export interface ResultSubmittedEvent {
  jobId: bigint;
  worker: Address;
  resultCID: Hex;
  transactionHash: Hash;
}

export interface JobSettledEvent {
  jobId: bigint;
  worker: Address;
  payment: bigint;
  transactionHash: Hash;
}
