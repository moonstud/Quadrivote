# Quadrivote 🧠📊

Quadrivote is a decentralized smart contract system designed for academic research councils to allocate funding fairly using **quadratic voting**, where influence is the square root of a researcher's academic credits. This ensures more democratic and reputation-weighted decision-making in grant approvals.

## 🎯 Purpose

To enable transparent, fair, and reputation-based evaluation of research proposals on-chain, prioritizing academic merit and peer consensus rather than raw stake or central authority.

## 💡 Key Features

- **Quadratic Voting Mechanism**: Influence is proportional to √(academic credits).
- **Research Proposal Submission**: Researchers with minimum credits can submit detailed funding proposals.
- **Peer Review System**: Verified researchers cast weighted votes with optional funding recommendations.
- **Review Period Enforcement**: Each proposal goes through a block-based timed review window (~15 days).
- **Reputation Tracking**: Profiles store metrics like total reviews submitted and proposals led.
- **Funding Status Lifecycle**: Tracks proposals from submission through funding or rejection to distribution.

## 🏗️ Smart Contract Design (Clarity)

### Constants
- `REVIEW-DURATION`: ~15 days
- `MIN-ACADEMIC-CREDITS`: u500
- `FUNDING-PROCESSING-TIME`: ~1.5 days

### Proposal States
- `UNDER-REVIEW`
- `REVIEW-ACTIVE`
- `FUNDING-APPROVED`
- `FUNDING-REJECTED`
- `FUNDS-DISTRIBUTED`
- `PROPOSAL-WITHDRAWN`

## 📦 Main Contract Components

### 📚 Maps
- `academic-credits`: Tracks each researcher's academic credit score.
- `research-proposals`: Stores submitted research project details and status.
- `peer-reviews`: Records individual peer review recommendations.
- `researcher-profiles`: Captures a researcher's engagement and leadership activity.

### 🔐 Public Functions
- `submit-research-proposal(...)`
- `submit-peer-review(...)`
- `conclude-review-process(...)`
- `distribute-funding(...)`
- `update-academic-credits(...)`
- `batch-credit-updates(...)`

### 🔎 Read-only Functions
- `get-research-proposal(...)`
- `get-peer-review(...)`
- `get-researcher-profile(...)`
- `get-academic-influence(...)`
- `get-funding-status(...)`
- `can-submit-research-proposal(...)`

## 🔐 Access Control
The `COUNCIL-CHAIR` (contract deployer) typically acts as the administrative or evaluative authority for academic credit assignment.

## ⚖️ Voting Principle

A reviewer with `100` credits has an influence of `10`, while one with `400` has an influence of `20`, preventing vote monopolies and promoting a fairer peer consensus system.

## 📈 Use Case

Ideal for academic institutions, grant funding DAOs, or decentralized research boards looking to automate and decentralize the proposal review and funding process using transparent on-chain logic.

## 🛠️ Future Improvements
- Multi-round voting for larger proposals
- On-chain credit reputation decay or incentive systems
- Integration with decentralized identity or verifiable credentials
