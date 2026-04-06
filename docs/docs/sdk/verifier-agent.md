# VerifierAgent

Finds submitted jobs, evaluates results, and attests on-chain.

## Constructor

```typescript
new VerifierAgent({
  addresses: ProtocolAddresses,
  publicClient: PublicClient,
  walletClient: WalletClient & { account: Account },
  ipfs: IPFSClient,
})
```

## Properties

### `publicClient: PublicClient`

Exposed for reading arbitrary contract state when needed.

## Methods

### `stake(amount: bigint): Promise<Hash>`

Deposit ETH as stake. Minimum `0.01 ETH` required to be assigned as verifier.

### `registerProfile(input: AgentProfileInput): Promise<Hash>`

Register capability profile on-chain. Must have `role: AgentRole.VERIFIER` or `AgentRole.BOTH`.

### `getPendingVerifications(opts?): Promise<Array<{ jobId: bigint; job: Job; resultCID: Hex }>>`

Find SUBMITTED jobs where this verifier is assigned.

Options:
- `fromBlock?: bigint`
- `maxResults?: number`

### `attestVerification(jobId: bigint, success: boolean): Promise<Hash>`

Attest the result. `true` → job becomes VERIFIED. `false` → job becomes DISPUTED.

### `castDisputeVote(jobId: bigint, supportsWorker: boolean): Promise<Hash>`

Vote in a multi-agent consensus dispute. Caller must be registered as a verifier.

### `raiseDispute(jobId: bigint): Promise<Hash>`

Raise a dispute for a SUBMITTED job. Challenger must have stake.

### `settleJob(jobId: bigint): Promise<Hash>`

Trigger settlement after challenge window. Anyone can call.

### `fetchResult<T>(resultCID: Hex): Promise<T>`

Download the worker's result from IPFS.

### `fetchJobInput<T>(job: Job): Promise<T>`

Download the original input data from IPFS.

### `fetchSuccessCriteria(job: Job): Promise<string>`

Download the evaluation rubric from IPFS.

### `getScore(address?: Address): Promise<bigint>`

Get reputation score (0–1000).
