const { expect } = require('chai');
const { ethers } = require('hardhat');
const { anyValue } = require('@nomicfoundation/hardhat-chai-matchers/withArgs');

describe('GibsMeDatToken', function () {
  let owner, treasury, addr1, addr2, token;
  const DEAD = '0x000000000000000000000000000000000000dEaD';

  beforeEach(async function () {
    [owner, treasury, addr1, addr2] = await ethers.getSigners();
    const Token = await ethers.getContractFactory('GibsMeDatToken');
    token = await Token.deploy(treasury.address);
    await token.waitForDeployment();
  });

  it('deploys with correct initial distribution and event', async function () {
    const total = await token.totalSupply();
    const expectedTotal = ethers.parseUnits('6942080085', 18);
    expect(total).to.equal(expectedTotal);

    const deadBal = await token.balanceOf(DEAD);
    const treasuryBal = await token.balanceOf(treasury.address);
    expect(deadBal).to.equal((expectedTotal * 10n) / 100n);
    expect(treasuryBal).to.equal((expectedTotal * 5n) / 100n);

    const deployTx = token.deploymentTransaction();
    await expect(deployTx)
      .to.emit(token, 'LongLiveTheTokenomics')
      .withArgs(owner.address);
  });

  it('applies transfer tax and emits events', async function () {
    const amount = ethers.parseUnits('1000', 18);
    const treasuryInitial = await token.balanceOf(treasury.address);
    const deadInitial = await token.balanceOf(DEAD);
    const tx = await token.transfer(addr1.address, amount);
    const fee = (amount * 69n) / 10000n;
    const reflectionFee = (amount * 30n) / 10000n;
    const treasuryFee = (amount * 30n) / 10000n;
    const burnFee = (amount * 9n) / 10000n;

    await expect(tx)
      .to.emit(token, 'RedistributionOfWealth')
      .withArgs(owner.address, fee);
    await expect(tx)
      .to.emit(token, 'GloriousContribution')
      .withArgs(treasuryFee);
    await expect(tx).to.emit(token, 'ToGulag').withArgs(burnFee);
    await expect(tx).to.emit(token, 'ComradeReward').withArgs(reflectionFee);
    await expect(tx)
      .to.emit(token, 'HoardersPunished')
      .withArgs(owner.address, fee);

    const received = await token.balanceOf(addr1.address);
    expect(received).to.equal(amount - fee);
    const treasuryDelta =
      (await token.balanceOf(treasury.address)) - treasuryInitial;
    expect(treasuryDelta).to.equal(treasuryFee);
    const deadDelta = (await token.balanceOf(DEAD)) - deadInitial;
    expect(deadDelta).to.equal(burnFee);
  });

  it('allows claiming reflections', async function () {
    const amount = ethers.parseUnits('1000', 18);
    await token.transfer(addr1.address, amount);
    await token.transfer(addr2.address, amount); // generates reflection for addr1
    const before = await token.balanceOf(addr1.address);
    const tx = await token.connect(addr1).claimReflection();
    await expect(tx)
      .to.emit(token, 'ReflectionClaimed')
      .withArgs(addr1.address, anyValue);
    const after = await token.balanceOf(addr1.address);
    expect(after).to.be.gt(before);
  });

  it('only owner can set treasury', async function () {
    await expect(token.connect(addr1).setTreasury(addr2.address)).to.be
      .reverted;
    await expect(token.setTreasury(addr2.address))
      .to.emit(token, 'TreasuryChanged')
      .withArgs(treasury.address, addr2.address);
    const Token = await ethers.getContractFactory('GibsMeDatToken');
    const other = await Token.deploy(addr1.address);
    await other.waitForDeployment();
    await expect(token.setTreasury(other.target)).to.be.revertedWith(
      'treasury contract'
    );
  });

  it('supports tax exemption and adjustable rates', async function () {
    await token.setTaxExempt(addr1.address, true);
    const amount = ethers.parseUnits('1000', 18);
    await token.transfer(addr1.address, amount);
    const received = await token.balanceOf(addr1.address);
    expect(received).to.equal(amount);
    await token.setTaxRates(0, 0, 0);
    await token.transfer(addr2.address, amount);
    const received2 = await token.balanceOf(addr2.address);
    expect(received2).to.equal(amount);
  });

  it('pauses and unpauses transfers', async function () {
    await token.pause();
    await expect(token.transfer(addr1.address, 1n)).to.be.revertedWith(
      'Pausable: paused'
    );
    await token.unpause();
    await expect(token.transfer(addr1.address, 1n)).to.not.be.reverted;
  });

  it('enforces max transfer amount', async function () {
    await token.setMaxTransferAmount(100n);
    await expect(token.transfer(addr1.address, 101n)).to.be.revertedWith(
      'max transfer exceeded'
    );
    await expect(token.transfer(addr1.address, 100n)).to.not.be.reverted;
  });

  it('rescues tokens sent to the contract', async function () {
    await token.transfer(token.target, 100n);
    const before = await token.balanceOf(owner.address);
    await token.rescueTokens(token.target, owner.address, 100n);
    const after = await token.balanceOf(owner.address);
    expect(after - before).to.equal(100n);
  });

  it('allows approvals via permit', async function () {
    const value = ethers.parseUnits('100', 18);
    const nonce = await token.nonces(owner.address);
    const deadline = ethers.MaxUint256;
    const domain = {
      name: 'Gibs Me Dat',
      version: '1',
      chainId: (await ethers.provider.getNetwork()).chainId,
      verifyingContract: token.target,
    };
    const types = {
      Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
      ],
    };
    const signature = await owner.signTypedData(domain, types, {
      owner: owner.address,
      spender: addr1.address,
      value,
      nonce,
      deadline,
    });
    const { v, r, s } = ethers.Signature.from(signature);
    await token.permit(owner.address, addr1.address, value, deadline, v, r, s);
    expect(await token.allowance(owner.address, addr1.address)).to.equal(value);
    await token
      .connect(addr1)
      .transferFrom(owner.address, addr1.address, value);
    expect(await token.allowance(owner.address, addr1.address)).to.equal(0n);
  });

  it('does not underflow when reflection credited exceeds new value', async function () {
    const amount = ethers.parseUnits('1000', 18);
    await token.setTaxExempt(addr1.address, true);
    await token.transfer(addr1.address, amount);
    await token.transfer(addr2.address, amount);
    await token.connect(addr1).claimReflection();
    const bal = await token.balanceOf(addr1.address);
    await token.connect(addr1).transfer(owner.address, bal);
    await expect(token.connect(addr1).claimReflection()).to.not.be.reverted;
  });
});
