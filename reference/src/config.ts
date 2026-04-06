import { createPublicClient, createWalletClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";
import type { ProtocolAddresses } from "@undergrid/sdk";
import { IPFSClient } from "@undergrid/sdk";

function requireEnv(key: string): string {
  const val = process.env[key];
  if (!val) throw new Error(`Missing required env var: ${key}`);
  return val;
}

export function createClients(privateKey: string) {
  const account = privateKeyToAccount(privateKey as `0x${string}`);
  const publicClient = createPublicClient({
    chain: baseSepolia,
    transport: http(process.env["RPC_URL"] ?? "https://sepolia.base.org"),
  });
  const walletClient = createWalletClient({
    account,
    chain: baseSepolia,
    transport: http(process.env["RPC_URL"] ?? "https://sepolia.base.org"),
  });
  return { account, publicClient, walletClient };
}

export function getAddresses(): ProtocolAddresses {
  return {
    jobRegistry: requireEnv("JOB_REGISTRY_ADDRESS") as `0x${string}`,
    escrow: requireEnv("ESCROW_ADDRESS") as `0x${string}`,
    stakingVault: requireEnv("STAKING_VAULT_ADDRESS") as `0x${string}`,
    agentRegistry: requireEnv("AGENT_REGISTRY_ADDRESS") as `0x${string}`,
    reputationSystem: requireEnv("REPUTATION_SYSTEM_ADDRESS") as `0x${string}`,
    disputeResolver: requireEnv("DISPUTE_RESOLVER_ADDRESS") as `0x${string}`,
  };
}

export function createIPFS() {
  return new IPFSClient({
    pinataJwt: process.env["PINATA_JWT"],
    gateway: process.env["IPFS_GATEWAY"] ?? "https://gateway.pinata.cloud",
  });
}
