# AGENTS

This repository uses **AGENTS.md** files to document contributor responsibilities, style conventions, and required checks. Instructions apply recursively to all files within a directory unless superseded by a nested `AGENTS.md`.

## General Guidelines

- Read all relevant `AGENTS.md` files before modifying or creating files.
- Write descriptive commit messages and keep the worktree clean.
- Run programmatic checks before committing:
  - `npx hardhat test` for Solidity contracts.
  - `npm test` for JavaScript/React code.
  - `npm run lint` where a linter is configured.
- Document architectural or economic decisions in the repository.
- Prefer multisig or DAO-controlled ownership (e.g., `GibsTreasuryDAO`) for administrative functions and document any DAO proposal that executes owner-only calls. Renounce ownership after migration when feasible.

## Roles

### Systems Designer

- Define overall architecture and ensure components interact cleanly.
- Maintain diagrams and update them as features evolve.

### Principal Full Stack (React, Fleek, Eth) Developer

- Integrate smart contracts with the front-end and deploy the site to Fleek.
- Manage environment configuration and blockchain connections.

### Senior Software Developer

- Oversee code quality across the project and enforce best practices.
- Review pull requests and keep dependencies up to date.

### Solidity Contract Engineer

- Implement and maintain Solidity contracts in `contracts/`.
- Write comprehensive tests and ensure `npx hardhat test` passes before commit.
- Optimize for security and gas efficiency, using OpenZeppelin libraries when possible.

### Security Auditor

- Review contracts and system design for vulnerabilities.
- Run static analysis tools when available and share findings.

### React UX Expert

- Define the user experience and ensure accessibility and responsiveness.
- Collaborate with developers to implement intuitive interfaces.

### React Developer

- Implement UI components using React functional components and hooks.
- Adhere to the design system and run `npm test`/`npm run lint` before committing.

### Economist

- Specify tokenomics and economic incentives for the ecosystem.
- Keep assumptions and formulas documented for transparency.

### Meme Expert

- Craft memes and messaging that reinforce the project's satirical tone.
- Ensure visual and textual humor aligns with the brand.

### Producer & Documentation

- Maintain README files, AGENTS files, and other documentation.
- Coordinate releases and keep changelogs accurate.

### DevOps Engineer

- Manage CI/CD pipelines and ensure reproducible builds.
- Monitor deployments and automate routine tasks where possible.

### QA Engineer

- Maintain automated test suites for contracts and front-end code.
- Track coverage and verify that regressions are caught early.

### Community Manager

- Engage with the community, gather feedback, and relay issues to the team.
- Coordinate announcements and social media presence.
