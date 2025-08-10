# HeritageVault

A blockchain-powered platform for preserving endangered cultural artifacts through decentralized provenance tracking, community-driven funding, and digital twin NFTs, empowering custodians and supporters to protect global heritage on-chain.

---

## Overview

HeritageVault is a Web3 platform designed to safeguard cultural heritage by creating immutable records, enabling transparent funding, and incentivizing community participation. Built on the Stacks blockchain using Clarity smart contracts, it leverages NFTs for artifact digital twins, DAOs for governance, and tokenized crowdfunding for preservation efforts. The platform addresses the loss of cultural artifacts due to theft, forgery, or insufficient resources by decentralizing control and ensuring transparency.

HeritageVault consists of four main smart contracts that form a secure, transparent, and community-driven ecosystem for cultural preservation:

1. **Artifact NFT Contract** – Manages the minting and tracking of NFTs representing digital twins of cultural artifacts.
2. **Preservation DAO Contract** – Enables token holders to vote on restoration projects and funding allocation.
3. **Crowdfunding Contract** – Facilitates tokenized crowdfunding for preservation initiatives with automated payouts.
4. **Royalty Distribution Contract** – Distributes royalties from NFT sales or loans to custodians and preservation funds.

---

## Features

- **Digital Twin NFTs** for artifacts, embedding provenance and 3D scan metadata (stored on IPFS).  
- **Immutable Provenance Tracking** to verify artifact authenticity and history.  
- **Community Governance** via a DAO for prioritizing preservation projects.  
- **Tokenized Crowdfunding** with milestone-based fund releases for restoration efforts.  
- **Royalty Sharing** for custodians and preservation initiatives from NFT sales or loans.  
- **Incentivized Participation** for contributors (e.g., 3D scanners, historians) via token rewards.  
- **Global Accessibility** to digital twins, reducing physical wear on artifacts.  
- **Oracle Integration** for verifying real-world restoration milestones.  

---

## Smart Contracts

### Artifact NFT Contract
- **Purpose**: Mints and manages NFTs representing digital twins of cultural artifacts, storing metadata (e.g., origin, history, IPFS hashes) on-chain.
- **Key Functions**:
  - `mint-artifact(principal recipient, string metadata-uri, uint artifact-id)`: Mints an NFT to a verified custodian (e.g., museum, community) after oracle verification.
  - `update-metadata(uint token-id, string new-metadata-uri)`: Updates NFT metadata (e.g., new scans or restoration data) with DAO approval.
  - `transfer-artifact(uint token-id, principal new-owner)`: Transfers NFT ownership, logging provenance on-chain.
- **Features**:
  - Enforces custodian verification via oracle or admin.
  - Emits events for off-chain indexing of provenance changes.
  - Restricts unauthorized metadata updates.

### Preservation DAO Contract
- **Purpose**: Enables token holders to propose and vote on preservation projects (e.g., restoring a temple or digitizing manuscripts).
- **Key Functions**:
  - `create-proposal(string description, uint funding-goal, principal crowdfunding-contract)`: Submits a preservation project for voting.
  - `vote(proposal-id uint, bool in-favor)`: Allows token holders to vote, weighted by token balance.
  - `execute-proposal(proposal-id uint)`: Executes approved proposals, triggering crowdfunding contract actions.
- **Features**:
  - Token-weighted voting with configurable quorum and voting periods.
  - Transparent proposal history and outcomes.
  - Restricts voting to staked token holders.

### Crowdfunding Contract
- **Purpose**: Facilitates tokenized crowdfunding for preservation projects, with funds released upon verified milestones (e.g., restoration phase completion).
- **Key Functions**:
  - `fund-project(proposal-id uint, uint amount)`: Allows contributors to pledge tokens to a project.
  - `release-funds(proposal-id uint, uint milestone-id)`: Releases funds to custodians upon oracle-verified milestones.
  - `refund-contributors(proposal-id uint)`: Refunds contributors if a project fails to meet milestones.
- **Features**:
  - Milestone-based fund release via oracle integration (e.g., Chainlink CCIP).
  - Transparent tracking of contributions and payouts.
  - Anti-fraud mechanisms to prevent premature fund releases.

### Royalty Distribution Contract
- **Purpose**: Distributes royalties from NFT sales or loans (e.g., for museum exhibitions) to custodians and preservation funds.
- **Key Functions**:
  - `distribute-royalties(uint token-id, uint amount)`: Splits royalties between custodians and a preservation treasury.
  - `set-royalty-rules(uint token-id, uint custodian-share, uint treasury-share)`: Configures royalty splits with DAO approval.
  - `withdraw-treasury(principal recipient, uint amount)`: Allows DAO to allocate treasury funds for new projects.
- **Features**:
  - Automated royalty splits (e.g., 70% to custodians, 30% to preservation fund).
  - Transparent royalty distribution logs.
  - DAO-governed treasury withdrawals.

---

## Installation

1. Install [Clarinet CLI](https://docs.hiro.so/clarinet/getting-started) for Stacks development.
2. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/heritagevault.git
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Run tests:
   ```bash
   clarinet test
   ```
5. Deploy contracts to the Stacks testnet:
   ```bash
   clarinet deploy --testnet
   ```

## Usage

Each smart contract is designed to operate independently but integrates seamlessly to form the HeritageVault ecosystem. To interact with the platform:
- **Custodians**: Use the Artifact NFT Contract to mint NFTs for verified artifacts, linking to IPFS metadata.
- **Community Members**: Stake tokens to participate in the Preservation DAO Contract and vote on projects.
- **Contributors**: Fund projects via the Crowdfunding Contract and track milestone progress.
- **Developers**: Refer to individual contract documentation in the `/contracts` folder for function calls, parameters, and integration details.

Example workflow:
1. A museum uploads a 3D scan of an ancient vase to IPFS and mints an NFT via the Artifact NFT Contract.
2. The Preservation DAO Contract approves a restoration project for the vase’s physical site.
3. Supporters fund the project through the Crowdfunding Contract using STX tokens.
4. Royalties from NFT loans to virtual exhibitions are distributed via the Royalty Distribution Contract.

## License

MIT License
