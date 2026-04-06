// @ts-nocheck
import {
  type PublicClient,
  type WalletClient,
  type Account,
  getContract,
} from "viem";
import {
  JobRegistryAbi,
  EscrowAbi,
  StakingVaultAbi,
  AgentRegistryAbi,
  ReputationSystemAbi,
  DisputeResolverAbi,
} from "./abis/index";
import type { ProtocolAddresses } from "./types";

// A contract instance with read and write methods (loosely typed for DTS compatibility).
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type ContractInstance = { read: Record<string, (...args: any[]) => any>; write: Record<string, (...args: any[]) => any>; };

export interface ProtocolContracts {
  jobRegistry: ContractInstance;
  escrow: ContractInstance;
  stakingVault: ContractInstance;
  agentRegistry: ContractInstance;
  reputationSystem: ContractInstance;
  disputeResolver: ContractInstance;
}

/**
 * Creates typed viem contract instances for every protocol contract.
 * viem v2 uses a single `client` object — pass `{ public, wallet }` for both read and write.
 */
export function getProtocolContracts(
  addresses: ProtocolAddresses,
  publicClient: PublicClient,
  walletClient?: WalletClient & { account: Account }
): ProtocolContracts {
  const client = walletClient
    ? { public: publicClient, wallet: walletClient }
    : publicClient;

  return {
    jobRegistry: getContract({ address: addresses.jobRegistry, abi: JobRegistryAbi, client }) as ContractInstance,
    escrow: getContract({ address: addresses.escrow, abi: EscrowAbi, client }) as ContractInstance,
    stakingVault: getContract({ address: addresses.stakingVault, abi: StakingVaultAbi, client }) as ContractInstance,
    agentRegistry: getContract({ address: addresses.agentRegistry, abi: AgentRegistryAbi, client }) as ContractInstance,
    reputationSystem: getContract({ address: addresses.reputationSystem, abi: ReputationSystemAbi, client }) as ContractInstance,
    disputeResolver: getContract({ address: addresses.disputeResolver, abi: DisputeResolverAbi, client }) as ContractInstance,
  };
}
