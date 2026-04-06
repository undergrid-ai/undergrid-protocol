# JobRegistry

The core state machine of the Undergrid protocol. All job lifecycle transitions go through here.

## State Machine

```
OPEN ──acceptJob()──► ACCEPTED ──submitResult()──► SUBMITTED
  │                                                    │
cancelJob()                          attestVerification(true)   attestVerification(false)
  │                                          │                          │
  ▼                                          ▼                          ▼
CANCELLED                               VERIFIED                   DISPUTED
                                             │                          │
                                        settleJob()           resolveDispute() / applyArbitrationOutcome()
                                             │                          │
                                             ▼                          ▼
                                          SETTLED                   RESOLVED
```

## Key Functions

### `createJob(JobSpec spec) payable → uint256 jobId`

Creates a new job. `msg.value` must equal `spec.payment`. Locks payment in `Escrow`.

Emits: `JobCreated(jobId, requester, payment)`

### `cancelJob(uint256 jobId)`

Only callable by `requester` while in `OPEN` state. Refunds payment.

### `acceptJob(uint256 jobId, address verifier)`

Called by a worker. Must have `≥ MIN_WORKER_STAKE` in `StakingVault`. `verifier` must also have `≥ MIN_VERIFIER_STAKE`.

Emits: `JobAccepted(jobId, worker)`, `VerifierAssigned(jobId, verifier)`

### `submitResult(uint256 jobId, bytes32 resultCID)`

Called by the assigned worker. Records result CID on-chain. Starts challenge window.

### `attestVerification(uint256 jobId, bool success)`

Called by the assigned verifier.
- `success = true`: job → `VERIFIED`
- `success = false`: job → `DISPUTED`

### `settleJob(uint256 jobId)`

Callable by anyone after challenge window elapses. Releases payment via `Escrow`.

### `applyDisputeOutcome(uint256 jobId, bool workerWon)`

Only callable by `DisputeResolver`. Releases or refunds based on outcome.

## Constants

| Name | Value |
|---|---|
| `PROTOCOL_FEE_BPS` | 50 (0.5%) |
| `MIN_CHALLENGE_WINDOW` | 1 hour |
| `MAX_CHALLENGE_WINDOW` | 7 days |
| `MIN_WORKER_STAKE` | 0.01 ETH |
| `MIN_VERIFIER_STAKE` | 0.01 ETH |
