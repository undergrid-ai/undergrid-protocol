/**
 * Reference: Verifier Agent — Summarization Quality Checker
 *
 * Picks up submitted jobs where this agent is the assigned verifier,
 * evaluates the result against the rubric, and attests on-chain.
 *
 * Run: JOB_ID=<id> tsx src/verifier/index.ts
 */
import { parseEther } from "viem";
import { VerifierAgent, AgentRole, IPFSClient } from "@undergrid/sdk";
import { createClients, getAddresses, createIPFS } from "../config.js";
import { verifyResult } from "./rubric.js";
import type { SummaryEntry } from "../worker/summarizer.js";

async function main() {
  console.log("=== Undergrid Reference: Verifier Agent ===\n");

  const privateKey = process.env["VERIFIER_PRIVATE_KEY"];
  if (!privateKey) throw new Error("Set VERIFIER_PRIVATE_KEY");

  const { publicClient, walletClient } = createClients(privateKey);
  const addresses = getAddresses();
  const ipfs = createIPFS();

  const verifier = new VerifierAgent({
    addresses,
    publicClient: publicClient as any,
    walletClient: walletClient as any,
    ipfs,
  });

  // 1. Stake if needed
  const verifierStake = await verifier.publicClient.readContract({
    address: addresses.stakingVault,
    abi: (await import("@undergrid/sdk")).StakingVaultAbi,
    functionName: "getStake",
    args: [walletClient.account.address],
  }) as bigint;
  if (verifierStake < parseEther("0.01")) {
    console.log("Staking 0.01 ETH...");
    await verifier.stake(parseEther("0.01"));
    console.log("Staked.");
  }

  // 2. Register if needed
  try {
    await verifier.registerProfile({
      capabilities: {
        version: "1.0",
        agentName: "summary-verifier",
        description: "Verifies summarization quality against rubrics",
        taskTypes: ["summarization", "verification"],
        supportedInputFormats: ["application/json"],
        supportedOutputFormats: ["application/json"],
        pricing: { minPriceWei: String(parseEther("0.001")), currency: "ETH" },
        latencyMs: { p50: 2000, p95: 5000 },
      },
      taskTypes: ["summarization", "verification"],
      pricePerJob: parseEther("0.001"),
      maxLatencySeconds: 30,
      role: AgentRole.VERIFIER,
    });
    console.log("Agent registered.");
  } catch {
    console.log("Agent already registered, continuing...");
  }

  // 3. Find pending verifications
  let jobId: bigint;

  if (process.env["JOB_ID"]) {
    jobId = BigInt(process.env["JOB_ID"]);
    console.log(`Using specified job ID: ${jobId}`);
  } else {
    console.log("Scanning for pending verifications...");
    const pending = await verifier.getPendingVerifications({ maxResults: 10 });

    if (pending.length === 0) {
      console.log("No pending verifications for this address.");
      process.exit(0);
    }

    jobId = pending[0].jobId;
    console.log(`Found pending verification for job ${jobId}`);
  }

  const { JobRegistryAbi } = await import("@undergrid/sdk");
  const jobRaw = await verifier.publicClient.readContract({
    address: addresses.jobRegistry,
    abi: JobRegistryAbi,
    functionName: "getJob",
    args: [jobId],
  }) as any;

  // 4. Fetch original input
  console.log("Fetching original input...");
  const inputCid = IPFSClient.bytes32ToCid(jobRaw.inputCID);
  const input = await ipfs.fetchJSON<{ documents: string[] }>(inputCid);

  // 5. Fetch submitted result
  const resultCidBytes = await verifier.publicClient.readContract({
    address: addresses.jobRegistry,
    abi: JobRegistryAbi,
    functionName: "getResultCID",
    args: [jobId],
  }) as `0x${string}`;

  console.log("Fetching submitted result...");
  const resultCid = IPFSClient.bytes32ToCid(resultCidBytes);
  const result = await ipfs.fetchJSON<SummaryEntry[]>(resultCid);

  // 6. Evaluate
  console.log("Evaluating result against rubric...");
  const report = verifyResult(result, input.documents);

  console.log(`\nVerification Report:`);
  console.log(`  Score:  ${report.score}/100`);
  console.log(`  Passed: ${report.passed}`);
  if (report.issues.length > 0) {
    console.log(`  Issues:`);
    report.issues.forEach((issue) => console.log(`    - ${issue}`));
  }

  // 7. Attest on-chain
  console.log(`\nAttesting verification (passed=${report.passed})...`);
  const txHash = await verifier.attestVerification(jobId, report.passed);
  console.log(`TxHash: ${txHash}`);

  if (report.passed) {
    // 8. Trigger settlement after challenge window (keeper function)
    console.log("\nVerification passed. Challenge window is now active.");
    console.log("Anyone can call settleJob() after the window to release payment.");
  } else {
    console.log("\nVerification failed. Job is now in DISPUTED state.");
  }
}

main().catch(console.error);
