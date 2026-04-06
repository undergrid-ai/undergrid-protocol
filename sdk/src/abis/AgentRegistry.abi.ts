export const AgentRegistryAbi = [
  {
    "type": "function",
    "name": "agentCount",
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
    "name": "deactivateAgent",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getAgentPage",
    "inputs": [
      {
        "name": "offset",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "limit",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "agents",
        "type": "address[]",
        "internalType": "address[]"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getProfile",
    "inputs": [
      {
        "name": "agent",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct IAgentRegistry.AgentProfile",
        "components": [
          {
            "name": "capabilitiesCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "taskTypes",
            "type": "string[]",
            "internalType": "string[]"
          },
          {
            "name": "pricePerJob",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxLatencySeconds",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "role",
            "type": "uint8",
            "internalType": "enum IAgentRegistry.AgentRole"
          },
          {
            "name": "active",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "registeredAt",
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
    "name": "hasRole",
    "inputs": [
      {
        "name": "agent",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "role",
        "type": "uint8",
        "internalType": "enum IAgentRegistry.AgentRole"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "isActive",
    "inputs": [
      {
        "name": "agent",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "registerAgent",
    "inputs": [
      {
        "name": "profile",
        "type": "tuple",
        "internalType": "struct IAgentRegistry.AgentProfile",
        "components": [
          {
            "name": "capabilitiesCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "taskTypes",
            "type": "string[]",
            "internalType": "string[]"
          },
          {
            "name": "pricePerJob",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxLatencySeconds",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "role",
            "type": "uint8",
            "internalType": "enum IAgentRegistry.AgentRole"
          },
          {
            "name": "active",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "registeredAt",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "updateProfile",
    "inputs": [
      {
        "name": "profile",
        "type": "tuple",
        "internalType": "struct IAgentRegistry.AgentProfile",
        "components": [
          {
            "name": "capabilitiesCID",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "taskTypes",
            "type": "string[]",
            "internalType": "string[]"
          },
          {
            "name": "pricePerJob",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxLatencySeconds",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "role",
            "type": "uint8",
            "internalType": "enum IAgentRegistry.AgentRole"
          },
          {
            "name": "active",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "registeredAt",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "AgentDeactivated",
    "inputs": [
      {
        "name": "agent",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AgentRegistered",
    "inputs": [
      {
        "name": "agent",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "role",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum IAgentRegistry.AgentRole"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "AgentUpdated",
    "inputs": [
      {
        "name": "agent",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AgentAlreadyRegistered",
    "inputs": [
      {
        "name": "agent",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "AgentNotActive",
    "inputs": [
      {
        "name": "agent",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "AgentNotFound",
    "inputs": [
      {
        "name": "agent",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "InvalidProfile",
    "inputs": []
  }
] as const;
