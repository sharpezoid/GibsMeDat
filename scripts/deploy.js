// Deploys the GibsMeDatToken which supports EIP-2612 permits.
const hre = require('hardhat');

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  const treasury = process.env.TREASURY || deployer.address;
  const Token = await hre.ethers.getContractFactory('GibsMeDatToken');
  const token = await Token.deploy(treasury);
  await token.waitForDeployment();
  console.log('GibsMeDatToken deployed to:', token.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
