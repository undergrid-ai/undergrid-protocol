# RequesterAgent

Creates and manages jobs on behalf of a requester wallet.

## Constructor

```typescript
new RequesterAgent({
  addresses: ProtocolAddresses,
  publicClient: PublicClient,
  walletClient: WalletClient & { account: Account },
  ipfs: IPFSClient,
})
```

## Methods

### `createJob(input: JobSpecInput): Promise<{ jobId: bigint; txHash: Hash }>`

Uploads all job content to IPFS, then posts the job on-chain with payment locked in escrow.

```typescript
const { jobId } = await requester.createJob({
  description: "...",          // uploaded to IPFS as text
  inputData: { ... },          // uploaded to IPFS as JSON
  outputSchema: { ... },       // uploaded to IPFS as JSON
  successCriteria: "...",      // uploaded to IPFS as text
  payment: parseEther("0.01"),
  verifierFee: parseEther("0.001"),
  bidDeadlineSeconds: 3600,
  challengeWindowSeconds: 7200,
  disputeType: DisputeMechanism.MULTI_AGENT_CONSENSUS,
});
```

### `createJobFromSpec(spec: JobSpec): Promise<{ jobId: bigint; txHash: Hash }>`

Post a job directly from a pre-built spec where CIDs are already computed. Use this if you've already uploaded to IPFS.

### `cancelJob(jobId: bigint): Promise<Hash>`

Cancel an OPEN job and receive a full refund. Only callable by the requester.

### `getJob(jobId: bigint): Promise<Job>`

Read the full job state from chain.

### `getJobCount(): Promise<bigint>`

Total number of jobs ever created.

### `getJobDescription(job: Job): Promise<string>`

Fetch the description text from IPFS.

## Types

### `JobSpecInput`

```typescript
interface JobSpecInput {
  description: string;
  inputData: unknown;
  outputSchema: unknown;
  successCriteria: string;
  payment: bigint;
  verifierFee: bigint;
  bidDeadlineSeconds: number;
  challengeWindowSeconds: number;
  disputeType: DisputeMechanism;
}
```
