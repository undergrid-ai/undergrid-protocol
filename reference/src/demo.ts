/**
 * End-to-end demo using Anvil local node (no real ETH needed).
 *
 * Runs the full protocol loop:
 *   1. Deploy contracts (assumes anvil is running with `forge script`)
 *   2. Requester creates job
 *   3. Worker accepts + submits
 *   4. Verifier attests
 *   5. Settlement
 *
 * Prerequisites:
 *   anvil                 — local EVM node
 *   forge script Deploy   — deploys contracts
 *
 * Run: tsx src/demo.ts
 */
import {
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { foundry } from "viem/chains";
import {
  RequesterAgent,
  WorkerAgent,
  VerifierAgent,
  IPFSClient,
  DisputeMechanism,
  AgentRole,
  JobState,
} from "@undergrid/sdk";
import type { ProtocolAddresses } from "@undergrid/sdk";
import { summarizeDocuments } from "./worker/summarizer.js";
import { verifyResult } from "./verifier/rubric.js";

// Anvil default test accounts
const ACCOUNTS = {
  requester: { key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" },
  worker: { key: "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" },
  verifier: { key: "0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a" },
};

// Addresses populated after forge script deployment (set via env or hardcode for demo)
const ADDRESSES: ProtocolAddresses = {
  jobRegistry: (process.env["JOB_REGISTRY_ADDRESS"] ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  escrow: (process.env["ESCROW_ADDRESS"] ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  stakingVault: (process.env["STAKING_VAULT_ADDRESS"] ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  agentRegistry: (process.env["AGENT_REGISTRY_ADDRESS"] ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  reputationSystem: (process.env["REPUTATION_SYSTEM_ADDRESS"] ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
  disputeResolver: (process.env["DISPUTE_RESOLVER_ADDRESS"] ?? "0x0000000000000000000000000000000000000000") as `0x${string}`,
};

const DOCUMENTS = [
  "Blockchain is a distributed ledger technology that enables secure, transparent, and immutable record-keeping without a central authority.",
  "Smart contracts are self-executing programs stored on a blockchain that automatically enforce and execute the terms of an agreement.",
  "Decentralized finance (DeFi) represents a shift from traditional, centralized financial systems to peer-to-peer finance enabled by blockchains.",
];

// Stub IPFS for local demo — stores data in memory
class StubIPFS extends IPFSClient {
  private store = new Map<string, string>();
  private counter = 0;

  override async uploadJSON(data: unknown): Promise<string> {
    const key = `stub-cid-${++this.counter}`;
    this.store.set(key, JSON.stringify(data));
    return key;
  }

  override async uploadText(text: string): Promise<string> {
    const key = `stub-cid-${++this.counter}`;
    this.store.set(key, text);
    return key;
  }

  override async fetchJSON<T>(cid: string): Promise<T> {
    const data = this.store.get(cid);
    if (!data) throw new Error(`Stub IPFS: key not found: ${cid}`);
    return JSON.parse(data) as T;
  }

  override async fetchText(cid: string): Promise<string> {
    const data = this.store.get(cid);
    if (!data) throw new Error(`Stub IPFS: key not found: ${cid}`);
    return data;
  }
}

async function main() {
  console.log("=== Undergrid E2E Demo (Local Anvil) ===\n");

  const rpcUrl = process.env["RPC_URL"] ?? "http://127.0.0.1:8545";
  const transport = http(rpcUrl);
  const ipfs = new StubIPFS();

  function makeClients(key: string) {
    const account = privateKeyToAccount(key as `0x${string}`);
    const publicClient = createPublicClient({ chain: foundry, transport });
    const walletClient = createWalletClient({ account, chain: foundry, transport });
    return { account, publicClient, walletClient };
  }

  const req = makeClients(ACCOUNTS.requester.key);
  const wrk = makeClients(ACCOUNTS.worker.key);
  const ver = makeClients(ACCOUNTS.verifier.key);

  const requesterAgent = new RequesterAgent({
    addresses: ADDRESSES,
    publicClient: req.publicClient as any,
    walletClient: req.walletClient as any,
    ipfs,
  });

  const workerAgent = new WorkerAgent({
    addresses: ADDRESSES,
    publicClient: wrk.publicClient as any,
    walletClient: wrk.walletClient as any,
    ipfs,
  });

  const verifierAgent = new VerifierAgent({
    addresses: ADDRESSES,
    publicClient: ver.publicClient as any,
    walletClient: ver.walletClient as any,
    ipfs,
  });

  // Step 1: Stake
  console.log("Step 1: Staking...");
  await workerAgent.stake(parseEther("0.1"));
  await verifierAgent.stake(parseEther("0.1"));
  console.log("  Worker and verifier staked.\n");

  // Step 2: Create job
  console.log("Step 2: Creating job...");
  const { jobId, txHash: createTx } = await requesterAgent.createJob({
    description: "Summarize each document. Return JSON array with index, summary, keywords.",
    inputData: { documents: DOCUMENTS },
    outputSchema: { type: "array" },
    successCriteria: "Each summary ≤ 100 chars, 2-5 keywords per entry.",
    payment: parseEther("0.01"),
    verifierFee: parseEther("0.001"),
    bidDeadlineSeconds: 3600,
    challengeWindowSeconds: 3600,
    disputeType: DisputeMechanism.MULTI_AGENT_CONSENSUS,
  });
  console.log(`  Job ID: ${jobId}, tx: ${createTx}\n`);

  // Step 3: Accept
  console.log("Step 3: Worker accepts job...");
  await workerAgent.acceptJob(jobId, ver.account.address);
  console.log("  Accepted.\n");

  // Step 4: Execute + submit
  console.log("Step 4: Worker summarizes and submits...");
  const job = await requesterAgent.getJob(jobId);
  const input = await workerAgent.fetchJobInput<{ documents: string[] }>(job);
  const summaries = await summarizeDocuments(input.documents);

  const { txHash: submitTx, resultCID } = await workerAgent.submitResult(jobId, summaries);
  console.log(`  Result submitted. tx: ${submitTx}\n`);

  // Step 5: Verify
  console.log("Step 5: Verifier evaluates and attests...");
  const report = verifyResult(summaries, input.documents);
  console.log(`  Score: ${report.score}/100, passed: ${report.passed}`);

  await verifierAgent.attestVerification(jobId, report.passed);
  console.log(`  Attested (passed=${report.passed}).\n`);

  // Step 6: Settle (fast-forward time if needed)
  if (report.passed) {
    console.log("Step 6: Settling job...");
    // On real network: wait for challenge window, then anyone calls settleJob
    // In demo: the challenge window is 1 hour, so we'd need to mine time
    console.log("  (In production: wait for challenge window to elapse, then call settleJob)\n");
  }

  console.log("=== Demo complete ===");
  console.log(`Final job state: ${JobState[job.state]}`);
}

main().catch(console.error);
