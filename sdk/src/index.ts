// Agents
export { RequesterAgent, WorkerAgent, VerifierAgent } from "./agents/index";
export type { RequesterConfig, WorkerConfig, VerifierConfig, VerificationResult } from "./agents/index";

// IPFS
export { IPFSClient } from "./ipfs/index";
export type { IPFSConfig } from "./ipfs/index";

// Contract bindings
export { getProtocolContracts } from "./contracts";
export type { ProtocolContracts } from "./contracts";

// ABIs
export {
  JobRegistryAbi,
  EscrowAbi,
  StakingVaultAbi,
  AgentRegistryAbi,
  ReputationSystemAbi,
  DisputeResolverAbi,
} from "./abis/index";

// Types
export {
  JobState,
  DisputeMechanism,
  AgentRole,
  BASE_SEPOLIA_ADDRESSES,
} from "./types";
export type {
  Job,
  JobSpec,
  JobSpecInput,
  AgentProfile,
  AgentProfileInput,
  AgentCapabilityManifest,
  AgentStats,
  ProtocolAddresses,
  JobCreatedEvent,
  ResultSubmittedEvent,
  JobSettledEvent,
} from "./types";
