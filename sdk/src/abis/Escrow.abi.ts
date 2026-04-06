export const EscrowAbi = [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_jobRegistry",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getLockedAmount",
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
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getVerifierFee",
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
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "jobRegistry",
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
    "name": "lockPayment",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "requester",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "verifierFee",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "refundPayment",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "requester",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "releasePayment",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
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
        "name": "feeRecipient",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "protocolFeeBps",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "PaymentLocked",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "PaymentRefunded",
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
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "PaymentReleased",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "recipient",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "VerifierFeePaid",
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
      },
      {
        "name": "fee",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AlreadyLocked",
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
    "name": "InsufficientBalance",
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
    "name": "NotJobRegistry",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotLocked",
    "inputs": [
      {
        "name": "jobId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ]
  }
] as const;
