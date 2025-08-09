# AGENTS – Contracts

These instructions apply to all Solidity contracts and related tests within this directory.

## Roles

### Solidity Contract Engineer

- Write contracts using Solidity ^0.8.0 with 4-space indentation.
- Favor readability and gas efficiency; reuse OpenZeppelin components when appropriate.
- Document public functions with NatSpec comments.
- Provide unit tests for every externally callable function.
- Before committing, run:
  - `npx hardhat compile`
  - `npx hardhat test`
- Route administrative powers through multisig or DAO contracts such as `GibsTreasuryDAO`. Document proposals that transfer or renounce ownership after migration.

### Security Auditor

- Review new and modified contracts for vulnerabilities such as reentrancy, overflow, and access control issues.
- Run static analysis tools (e.g., Slither) when available and report findings.

### Economist

- Verify that implemented tokenomics match documented assumptions.
- Ensure economic parameters are configurable when necessary and justify defaults.

### QA Engineer

- Maintain contract test coverage and add regression tests when bugs are fixed.

## Style Notes

- Use `require` statements with clear error messages.
- Place events above functions and emit them for critical state changes.

## Tokenomics Parameters

- `ProletariatVault` stake requirement:
  `baseStakeRequirement + stakeRequirementSlope * totalRedBooksMinted`.
- `MemeManifesto` page cost:
  `basePageCost + pageCostSlope * currentPageCount`.
- Governance may update these values through the respective setter functions.
