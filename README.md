# Gibs Me Dat ($GIBS)

Satirical meme ecosystem consisting of:

- **GibsMeDatToken**: ERC20 with 6.9% tax (3% reflection, 3% treasury, 0.9% burn), initial Gulag burn, and EIP-2612 permit for gasless approvals.
- **ProletariatVault**: ERC1155 staking vaults tracking meme yield.
- **MemeManifesto**: On-chain collaborative manifesto gated by RedBook Maximalists.
- **GibsTreasuryDAO**: Simple DAO where RedBook holders allocate treasury funds.

Static page located in `site/` can be deployed to [Fleek](https://fleek.co) for decentralised hosting. The root-level `index.html` simply redirects to this folder so that a default page is served when Fleek points to the repository root.

## Development

Compile contracts with Hardhat:

```bash
npm install
npx hardhat compile
```

Deploy the token (which supports `permit`) with Hardhat:

```bash
npx hardhat run scripts/deploy.js
```
