const { expect } = require('chai');
const { distribute } = require('../scripts/initialDistribution');
const { ethers } = require('hardhat');

describe('initialDistribution script', function () {
  const MIN_DELAY = 2 * 24 * 60 * 60;

  it('supports dry-run without changing balances', async function () {
    const [owner, recipient] = await ethers.getSigners();
    const Timelock = await ethers.getContractFactory('TimelockMock');
    const treasury = await Timelock.deploy(MIN_DELAY);
    await treasury.waitForDeployment();
    const Token = await ethers.getContractFactory('GibsMeDatToken');
    const token = await Token.deploy(treasury.target);
    await token.waitForDeployment();

    const recipients = [{ address: recipient.address, amount: 100 }];
    const beforeOwner = await token.balanceOf(owner.address);
    await distribute(token.target, recipients, { dryRun: true });
    const afterOwner = await token.balanceOf(owner.address);
    const recipientBal = await token.balanceOf(recipient.address);

    expect(afterOwner).to.equal(beforeOwner);
    expect(recipientBal).to.equal(0n);
  });

  it('transfers tokens when not a dry run', async function () {
    const [, recipient] = await ethers.getSigners();
    const Timelock = await ethers.getContractFactory('TimelockMock');
    const treasury = await Timelock.deploy(MIN_DELAY);
    await treasury.waitForDeployment();
    const Token = await ethers.getContractFactory('GibsMeDatToken');
    const token = await Token.deploy(treasury.target);
    await token.waitForDeployment();

    const recipients = [{ address: recipient.address, amount: 50 }];
    await distribute(token.target, recipients);
    const recipientBal = await token.balanceOf(recipient.address);

    expect(recipientBal).to.equal(50n);
  });
});
