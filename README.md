# Gibs Me Dat ($GIBS)

Satirical meme ecosystem consisting of:

- **GibsMeDatToken**: ERC20 with 0.69% tax (0.3% reflection, 0.3% treasury, 0.09% burn), initial Gulag burn, and EIP-2612 permit for gasless approvals.
- **ProletariatVault**: ERC1155 staking vaults tracking meme yield.
- **MemeManifesto**: On-chain collaborative manifesto gated by RedBook Maximalists.
- **GibsTreasuryDAO**: Simple DAO where RedBook holders allocate treasury funds.

Static page located in `site/` can be deployed to [Fleek](https://fleek.co) for decentralised hosting. The root-level `index.html` simply redirects to this folder so that a default page is served when Fleek points to the repository root.

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
