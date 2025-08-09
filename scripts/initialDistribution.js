const fs = require('fs');
const hre = require('hardhat');

async function distribute(tokenAddress, recipients, { dryRun = false } = {}) {
  const token = await hre.ethers.getContractAt('GibsMeDatToken', tokenAddress);
  for (const { address, amount } of recipients) {
    const value = BigInt(amount);
    if (dryRun) {
      console.log(`[dry-run] Would transfer ${value} tokens to ${address}`);
    } else {
      const tx = await token.transfer(address, value);
      await tx.wait();
      console.log(`Transferred ${value} tokens to ${address}`);
    }
  }
}

async function main() {
  const [file, tokenAddress, maybeDry] = process.argv.slice(2);
  const dryRun = maybeDry === '--dry-run';
  if (!file || !tokenAddress) {
    console.error(
      'Usage: node scripts/initialDistribution.js <recipients.json> <token-address> [--dry-run]'
    );
    process.exit(1);
  }
  const data = fs.readFileSync(file, 'utf8');
  const recipients = JSON.parse(data);
  await distribute(tokenAddress, recipients, { dryRun });
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { distribute };
