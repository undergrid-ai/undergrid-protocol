/**
 * Reference: Requester Agent — Batch Document Summarizer
 *
 * Posts a job asking a worker to summarize 10 documents.
 * Run: tsx src/requester/index.ts
 */
import { parseEther } from "viem";
import { RequesterAgent, DisputeMechanism } from "@undergrid/sdk";
import { createClients, getAddresses, createIPFS } from "../config.js";

const DOCUMENTS = [
  "The quick brown fox jumps over the lazy dog. This classic pangram contains every letter of the English alphabet and has been used in typing practice for decades.",
  "Blockchain technology provides a decentralized ledger that records transactions across many computers. Once recorded, the data in any given block cannot be altered retroactively.",
  "Machine learning is a method of data analysis that automates analytical model building. It is based on the idea that systems can learn from data, identify patterns, and make decisions.",
  "TypeScript is a strongly typed programming language that builds on JavaScript, giving you better tooling at any scale. It adds optional static typing and class-based OOP.",
  "Decentralized finance, or DeFi, refers to financial services using smart contracts on blockchains, primarily Ethereum, that do not depend on central financial intermediaries.",
  "Smart contracts are self-executing contracts with terms of agreement between buyer and seller being directly written into lines of code. They run on blockchain networks.",
  "IPFS, the InterPlanetary File System, is a protocol and peer-to-peer network for storing and sharing data in a distributed file system using content-addressing.",
  "Zero-knowledge proofs allow one party to prove to another that a given statement is true, without conveying any additional information beyond the fact that the statement is indeed true.",
  "Layer 2 solutions are secondary frameworks built on top of existing blockchain systems to improve scalability by processing transactions off the main chain.",
  "Tokenomics refers to the economic policies and incentive structures built into a blockchain protocol or token — covering supply, distribution, and utility.",
];

const OUTPUT_SCHEMA = {
  type: "array",
  items: {
    type: "object",
    properties: {
      index: { type: "number" },
      summary: { type: "string", maxLength: 100 },
      keywords: { type: "array", items: { type: "string" } },
    },
    required: ["index", "summary", "keywords"],
  },
};

const SUCCESS_CRITERIA = `
Each document must have a summary of no more than 100 characters.
Each summary must capture the main topic of the original document.
Each entry must include 2-5 keywords extracted from the document.
Output must be valid JSON matching the provided schema.
`;

async function main() {
  console.log("=== Undergrid Reference: Requester Agent ===\n");

  const privateKey = process.env["REQUESTER_PRIVATE_KEY"];
  if (!privateKey) throw new Error("Set REQUESTER_PRIVATE_KEY");

  const { publicClient, walletClient } = createClients(privateKey);
  const addresses = getAddresses();
  const ipfs = createIPFS();

  const requester = new RequesterAgent({
    addresses,
    publicClient: publicClient as any,
    walletClient: walletClient as any,
    ipfs,
  });

  const verifierAddress = process.env["VERIFIER_ADDRESS"] as `0x${string}` | undefined;

  console.log("Creating job...");
  console.log(`  Documents: ${DOCUMENTS.length}`);
  console.log(`  Payment: 0.01 ETH`);

  const { jobId, txHash } = await requester.createJob({
    description: "Summarize each of the provided documents. Return a JSON array with one entry per document, each containing an index, a summary (max 100 chars), and 2-5 keywords.",
    inputData: { documents: DOCUMENTS },
    outputSchema: OUTPUT_SCHEMA,
    successCriteria: SUCCESS_CRITERIA,
    payment: parseEther("0.01"),
    verifierFee: parseEther("0.001"),
    bidDeadlineSeconds: 3600,     // 1 hour
    challengeWindowSeconds: 7200, // 2 hours
    disputeType: DisputeMechanism.MULTI_AGENT_CONSENSUS,
  });

  console.log(`\nJob created!`);
  console.log(`  Job ID:  ${jobId}`);
  console.log(`  TxHash:  ${txHash}`);
  console.log(`\nWaiting for a worker to accept...`);
  console.log(`\nShare this job ID with the worker: ${jobId}`);
}

main().catch(console.error);
