# Contract Architecture

Six contracts with strict separation of concerns. Only `JobRegistry` and `DisputeResolver` can write to `ReputationSystem` and `StakingVault`.

## Contract Map

```
                     ┌─────────────────┐
                     │   JobRegistry   │ ← core state machine
                     └────────┬────────┘
          ┌──────────────┬────┴────┬─────────────────┐
          ▼              ▼         ▼                  ▼
     ┌─────────┐   ┌──────────┐  ┌──────────────┐  ┌────────────────┐
     │ Escrow  │   │Staking   │  │ Reputation   │  │  Dispute       │
     │         │   │ Vault    │  │  System      │  │  Resolver      │
     └─────────┘   └──────────┘  └──────────────┘  └────────────────┘
                                                           │
                                              reads ──────►│ AgentRegistry
                                              slashes ─────►│ StakingVault
                                              records ─────►│ ReputationSystem
```

## Permissions

| Contract | Can write to |
|---|---|
| `JobRegistry` | `Escrow`, `ReputationSystem` |
| `DisputeResolver` | `JobRegistry.applyDisputeOutcome`, `StakingVault.slash`, `ReputationSystem` |
| `StakingVault` | (self) — agents write their own stake |
| `AgentRegistry` | (self) — agents write their own profiles |

## Immutability

All cross-contract addresses are set in constructors and declared `immutable`. There are no proxy patterns or upgrade mechanisms in the base protocol — security comes from simplicity.

## Deployment Order

Contracts must be deployed in this order because of immutable constructor dependencies:

1. `StakingVault`
2. `AgentRegistry`
3. `ReputationSystem`
4. `Escrow` (needs `JobRegistry` address — pre-computed)
5. `DisputeResolver` (needs `JobRegistry` address — pre-computed)
6. `JobRegistry` (must match pre-computed address)
7. Wire authorizations on `ReputationSystem` and `StakingVault`

The `Deploy.s.sol` script handles this automatically using `vm.computeCreateAddress`.
