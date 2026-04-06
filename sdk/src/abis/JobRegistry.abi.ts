export const JobRegistryAbi = [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_escrow",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_reputation",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_disputeResolver",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_stakingVault",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "_feeRecipient",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "MAX_CHALLENGE_WINDOW",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MIN_CHALLENGE_WINDOW",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MIN_VERIFIER_STAKE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MIN_WORKER_STAKE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "PROTOCOL_FEE_BPS",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "acceptJob",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "verifier",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "applyDisputeOutcome",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "workerWon",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "attestVerification",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "success",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "cancelJob",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "createJob",
    "inputs": [
      {
        "name": "spec",
        "type": "tuple",
        "internalType": "struct IJobRegistry.JobSpec",
        "components": [
          {
            "name": "descriptionCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "inputCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "outputSchemaCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "successCriteriaCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "payment",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "verifierFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "bidDeadline",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "challengeWindow",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "disputeType",
            "type": "uint8",
            "internalType": "enum IJobRegistry.DisputeMechanism"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "disputeResolver",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IDisputeResolver"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "escrow",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IEscrow"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "feeRecipient",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getJob",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct IJobRegistry.Job",
        "components": [
          {
            "name": "descriptionCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "inputCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "outputSchemaCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "successCriteriaCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "payment",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "verifierFee",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "bidDeadline",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "challengeWindow",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "requester",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "worker",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "verifier",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "disputeType",
            "type": "uint8",
            "internalType": "enum IJobRegistry.DisputeMechanism"
          },
          {
            "name": "state",
            "type": "uint8",
            "internalType": "enum IJobRegistry.JobState"
          },
          {
            "name": "createdAt",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "acceptedAt",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "submittedAt",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getResultCID",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "jobCount",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "markJobDisputed",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "reputation",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IReputationSystem"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "settleJob",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "stakingVault",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IStakingVault"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "submitResult",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "resultCID",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "JobAccepted",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "worker",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "JobCancelled",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "JobCreated",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "requester",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "payment",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "JobDisputed",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "challenger",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "JobResolved",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "workerWon",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "JobSettled",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "worker",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "payment",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "JobVerified",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "verifier",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ResultSubmitted",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "worker",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "resultCID",
        "type": "bytes32",
        "indexed": false,
        "internalType": "bytes32"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "VerifierAssigned",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "verifier",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "BidDeadlinePassed",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "ChallengeWindowActive",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "InsufficientPayment",
    "inputs": [
      {
        "name": "required",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "provided",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "InvalidBidDeadline",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidChallengeWindow",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidState",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "current",
        "type": "uint8",
        "internalType": "enum IJobRegistry.JobState"
      },
      {
        "name": "required",
        "type": "uint8",
        "internalType": "enum IJobRegistry.JobState"
      }
    ]
  },
  {
    "type": "error",
    "name": "JobNotFound",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  },
  {
    "type": "error",
    "name": "NotRequester",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "caller",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "NotVerifier",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "caller",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "NotWorker",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "caller",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "ZeroAddress",
    "inputs": []
  }
] as const;
