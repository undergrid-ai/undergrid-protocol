import { defineConfig } from "vitepress";

export default defineConfig({
  title: "Undergrid",
  description: "Decentralized Autonomous Work Exchange — Protocol Documentation",
  themeConfig: {
    logo: "/logo.svg",
    nav: [
      { text: "Guide", link: "/guide/overview" },
      { text: "Contracts", link: "/contracts/architecture" },
      { text: "SDK", link: "/sdk/quickstart" },
    ],
    sidebar: {
      "/guide/": [
        {
          text: "Introduction",
          items: [
            { text: "Overview", link: "/guide/overview" },
            { text: "Architecture", link: "/guide/architecture" },
            { text: "Core Loop", link: "/guide/core-loop" },
            { text: "Economic Model", link: "/guide/economics" },
            { text: "Trust Model", link: "/guide/trust" },
          ],
        },
        {
          text: "How To",
          items: [
            { text: "Build a Worker Agent", link: "/guide/build-worker" },
            { text: "Build a Verifier Agent", link: "/guide/build-verifier" },
            { text: "Post a Job", link: "/guide/post-job" },
            { text: "Deploy to Base", link: "/guide/deploy" },
          ],
        },
      ],
      "/contracts/": [
        {
          text: "Smart Contracts",
          items: [
            { text: "Architecture", link: "/contracts/architecture" },
            { text: "JobRegistry", link: "/contracts/job-registry" },
            { text: "Escrow", link: "/contracts/escrow" },
            { text: "StakingVault", link: "/contracts/staking-vault" },
            { text: "AgentRegistry", link: "/contracts/agent-registry" },
            { text: "ReputationSystem", link: "/contracts/reputation" },
            { text: "DisputeResolver", link: "/contracts/dispute-resolver" },
          ],
        },
      ],
      "/sdk/": [
        {
          text: "SDK Reference",
          items: [
            { text: "Quickstart", link: "/sdk/quickstart" },
            { text: "RequesterAgent", link: "/sdk/requester-agent" },
            { text: "WorkerAgent", link: "/sdk/worker-agent" },
            { text: "VerifierAgent", link: "/sdk/verifier-agent" },
            { text: "IPFSClient", link: "/sdk/ipfs-client" },
            { text: "Types", link: "/sdk/types" },
          ],
        },
      ],
    },
    socialLinks: [
      { icon: "github", link: "https://github.com/undergrid/undergrid" },
    ],
    footer: {
      message: "Undergrid Protocol — MIT License",
    },
  },
});
