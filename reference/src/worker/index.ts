/**
 * Reference: Worker Agent — GPT-4o-mini Document Summarizer
 *
 * Discovers open summarization jobs, executes them, and submits results.
 * Run: JOB_ID=<id> tsx src/worker/index.ts
 */
import { parseEther } from "viem";
import { WorkerAgent, AgentRole, IPFSClient } from "@undergrid/sdk";
import { createClients, getAddresses, createIPFS } from "../config.js";
import { summarizeDocuments } from "./summarizer.js";

async function main() {
  console.log("=== Undergrid Reference: Worker Agent ===\n");

  const privateKey = process.env["WORKER_PRIVATE_KEY"];
  if (!privateKey) throw new Error("Set WORKER_PRIVATE_KEY");

  const verifierAddress = process.env["VERIFIER_ADDRESS"] as `0x${string}`;
  if (!verifierAddress) throw new Error("Set VERIFIER_ADDRESS");

  const { publicClient, walletClient } = createClients(privateKey);
  const addresses = getAddresses();
  const ipfs = createIPFS();

  const worker = new WorkerAgent({
    addresses,
    publicClient: publicClient as any,
    walletClient: walletClient as any,
    ipfs,
  });

  // 1. Stake if not already staked
  const stake = await worker.getStake();
  if (stake < parseEther("0.01")) {
    console.log("Staking 0.01 ETH...");
    await worker.stake(parseEther("0.01"));
    console.log("Staked.");
  } else {
    console.log(`Current stake: ${stake} wei`);
  }

  // 2. Register profile (skip if already registered)
  try {
    await worker.registerProfile({
      capabilities: {
        version: "1.0",
        agentName: "gpt4o-summarizer",
        description: "Summarizes documents using GPT-4o-mini",
        taskTypes: ["summarization", "text-processing"],
        supportedInputFormats: ["application/json"],
        supportedOutputFormats: ["application/json"],
        pricing: { minPriceWei: String(parseEther("0.005")), currency: "ETH" },
        latencyMs: { p50: 15000, p95: 30000 },
        tools: ["openai-gpt4o-mini"],
      },
      taskTypes: ["summarization", "text-processing"],
      pricePerJob: parseEther("0.005"),
      maxLatencySeconds: 120,
      role: AgentRole.WORKER,
    });
    console.log("Agent registered.");
  } catch {
    console.log("Agent already registered, continuing...");
  }

  // 3. Find or use specific job
  const targetJobId = process.env["JOB_ID"] ? BigInt(process.env["JOB_ID"]) : null;

  let jobId: bigint;
  if (targetJobId) {
    jobId = targetJobId;
    console.log(`Using specified job ID: ${jobId}`);
  } else {
    console.log("Discovering open jobs...");
    const jobs = await worker.discoverOpenJobs({ maxResults: 10 });
    const summJobs = jobs.filter(({ job }) => {
      // We'd normally filter by capability from the off-chain API
      return true;
    });

    if (summJobs.length === 0) {
      console.log("No open jobs found. Run the requester first.");
      process.exit(0);
    }

    jobId = summJobs[0].jobId;
    console.log(`Found job ${jobId}`);
  }

  const job = await worker.getJob(jobId);
  console.log(`Job state: ${job.state}`);

  // 4. Accept job
  console.log(`\nAccepting job ${jobId}...`);
  await worker.acceptJob(jobId, verifierAddress);
  console.log("Job accepted.");

  // 5. Download input
  console.log("Downloading job input from IPFS...");
  const input = await worker.fetchJobInput<{ documents: string[] }>(job);
  console.log(`  ${input.documents.length} documents to summarize`);

  // 6. Execute work
  console.log("Summarizing documents...");
  const startTime = Date.now();
  const summaries = await summarizeDocuments(input.documents);
  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`  Done in ${elapsed}s`);

  // 7. Submit result
  console.log("Submitting result...");
  const { txHash, resultCID } = await worker.submitResult(jobId, summaries);

  console.log(`\nResult submitted!`);
  console.log(`  TxHash:    ${txHash}`);
  console.log(`  ResultCID: ${resultCID}`);
  console.log(`\nNow waiting for verifier to attest the result.`);
  console.log(`Share result CID with verifier: ${IPFSClient.bytes32ToCid(resultCID)}`);
}

main().catch(console.error);
