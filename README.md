# Gibs Me Dat ($GIBS)

Satirical meme ecosystem consisting of:

- **GibsMeDatToken**: ERC20 with 0.69% tax (0.3% reflection, 0.3% treasury, 0.09% burn), initial Gulag burn, and EIP-2612 permit for gasless approvals.
- **ProletariatVault**: ERC1155 staking vaults tracking meme yield.
- **MemeManifesto**: On-chain collaborative manifesto gated by RedBook Maximalists.
- **GibsTreasuryDAO**: Simple DAO where RedBook holders allocate treasury funds.

Static page located in `site/` can be deployed to [Fleek](https://fleek.co) for decentralised hosting. The root-level `index.html` simply redirects to this folder so that a default page is served when Fleek points to the repository root.

## Governance

The treasury is controlled by an on-chain timelock. `GibsMeDatToken` enforces that the treasury address is a contract implementing `getMinDelay()`, typically an OpenZeppelin `TimelockController`. This delay gives comrades time to review withdrawals before execution.

## Owner-adjustable parameters

The Supreme Leader (token owner) can modify several parameters in `GibsMeDatToken.sol`. Changes to these values can affect fees, transfer limits, and overall holder experience.

- **Transfer taxes** – [`setTaxRates(uint256 _reflectionTax, uint256 _treasuryTax, uint256 _burnTax)`](contracts/GibsMeDatToken.sol#L117-L130) adjusts how the transfer tax is split between reflections, the treasury, and burns. The sum updates `transferTax`, altering the fee paid on each transfer.
- **Max total tax** – [`scheduleMaxTotalTaxIncrease(uint256 amount)`](contracts/GibsMeDatToken.sol#L132-L139) and [`setMaxTotalTax(uint256 amount)`](contracts/GibsMeDatToken.sol#L150-L162) raise or lower the ceiling on transfer taxes (in basis points). Increases require a two-day delay, enabling higher fees only after notice.
- **Tax exemptions** – [`setTaxExempt(address account, bool exempt)`](contracts/GibsMeDatToken.sol#L164-L168) can exempt addresses from taxes and transfer limits, potentially favoring certain holders.
- **Max transfer amount** – [`setMaxTransferAmount(uint256 amount)`](contracts/GibsMeDatToken.sol#L170-L174) caps how many tokens a non-exempt address may send in one transaction. Zero removes the cap and lifting it can restrict or free large movements.
- **Treasury address** – [`setTreasury(address newTreasury)`](contracts/GibsMeDatToken.sol#L87-L94) changes where the treasury share of taxes is sent. The new address must itself be governed by a timelock.
- **Emergency controls** – [`pause()`](contracts/GibsMeDatToken.sol#L176-L179) and [`unpause()`](contracts/GibsMeDatToken.sol#L181-L184) let the owner halt or resume all token transfers.
- **Token rescue** – [`rescueTokens(address token, address to, uint256 amount)`](contracts/GibsMeDatToken.sol#L186-L198) allows recovery of tokens mistakenly sent to the contract, excluding GIBS earmarked for reflections.

## Front-end checks

From `site/`, install dependencies and run:

```bash
npm ci
npm test
npm run lint
```

## Tokenomics

### Dynamic staking cost

`ProletariatVault` enforces a growing minimum stake:

```
currentStakeRequirement = baseStakeRequirement + stakeRequirementSlope * totalRedBooksMinted
```

Governance can adjust `baseStakeRequirement` and `stakeRequirementSlope` via `setStakeParameters`.

### Variable page submission cost

Adding a page to the `MemeManifesto` burns RedBooks based on the number of pages already written in the current chapter:

```
currentPageCost = basePageCost + pageCostSlope * currentPageCount
```

Administrators may tune `basePageCost` and `pageCostSlope` using `setPageCostParameters`.

## Development

Compile contracts with Hardhat:

```bash
npm install
npx hardhat compile
```

Deploy the token (which supports `permit`) with Hardhat. Set the `TREASURY` environment variable to the treasury address that should receive taxes:

```bash
TREASURY=<treasury-address> npx hardhat run scripts/deploy.js --network <network>
```

On Windows, a helper script is provided which sets `TREASURY` for you:

```bat
scripts\deploy.bat <network> <treasury-address>
```
