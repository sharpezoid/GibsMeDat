const { expect } = require('chai');
const { ethers } = require('hardhat');
const { anyValue } = require('@nomicfoundation/hardhat-chai-matchers/withArgs');

describe('GibsMeDatToken', function () {
  let owner, addr1, addr2, token, treasury;
  const DEAD = '0x000000000000000000000000000000000000dEaD';

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    const Timelock = await ethers.getContractFactory('TimelockMock');
    treasury = await Timelock.deploy(1);
    await treasury.waitForDeployment();
    const Token = await ethers.getContractFactory('GibsMeDatToken');
    token = await Token.deploy(treasury.target);
    await token.waitForDeployment();
  });

  it('deploys with correct initial distribution and event', async function () {
    const total = await token.totalSupply();
    const expectedTotal = ethers.parseUnits('6942080085', 18);
    expect(total).to.equal(expectedTotal);

    const deadBal = await token.balanceOf(DEAD);
    const treasuryBal = await token.balanceOf(treasury.target);
    expect(deadBal).to.equal((expectedTotal * 10n) / 100n);
    expect(treasuryBal).to.equal((expectedTotal * 5n) / 100n);

    const deployTx = token.deploymentTransaction();
    await expect(deployTx)
      .to.emit(token, 'LongLiveTheTokenomics')
      .withArgs(owner.address);
  });

  it('applies transfer tax and emits events', async function () {
    const amount = ethers.parseUnits('1000', 18);
    const treasuryInitial = await token.balanceOf(treasury.target);
    const deadInitial = await token.balanceOf(DEAD);
    const tx = await token.transfer(addr1.address, amount);
    const reflectionFee = (amount * 30n) / 10000n;
    const treasuryFee = (amount * 30n) / 10000n;
    const burnFee = (amount * 9n) / 10000n;
    const fee = reflectionFee + treasuryFee + burnFee;

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
      (await token.balanceOf(treasury.target)) - treasuryInitial;
    expect(treasuryDelta).to.equal(treasuryFee);
    const deadDelta = (await token.balanceOf(DEAD)) - deadInitial;
    expect(deadDelta).to.equal(burnFee);
  });

  it('sums fee components to prevent rounding loss', async function () {
    const amounts = [145n, 9999n];
    for (const amt of amounts) {
      const prevRecipient = await token.balanceOf(addr1.address);
      const prevTreasury = await token.balanceOf(treasury.target);
      const prevDead = await token.balanceOf(DEAD);
      const prevContract = await token.balanceOf(token.target);

      const reflectionFee = (amt * 30n) / 10000n;
      const treasuryFee = (amt * 30n) / 10000n;
      const burnFee = (amt * 9n) / 10000n;
      const fee = reflectionFee + treasuryFee + burnFee;
      const totalFee = (amt * 69n) / 10000n;
      expect(totalFee).to.not.equal(fee);

      const tx = await token.transfer(addr1.address, amt);

      if (fee > 0n) {
        await expect(tx)
          .to.emit(token, 'RedistributionOfWealth')
          .withArgs(owner.address, fee);
        await expect(tx)
          .to.emit(token, 'HoardersPunished')
          .withArgs(owner.address, fee);
      } else {
        await expect(tx).to.not.emit(token, 'RedistributionOfWealth');
        await expect(tx).to.not.emit(token, 'HoardersPunished');
      }

      const newRecipient = await token.balanceOf(addr1.address);
      expect(newRecipient - prevRecipient).to.equal(amt - fee);

      const newTreasury = await token.balanceOf(treasury.target);
      expect(newTreasury - prevTreasury).to.equal(treasuryFee);

      const newDead = await token.balanceOf(DEAD);
      expect(newDead - prevDead).to.equal(burnFee);

      const newContract = await token.balanceOf(token.target);
      expect(newContract - prevContract).to.equal(reflectionFee);
    }
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

  it('preserves reflection balance after burn', async function () {
    const amount = ethers.parseUnits('1000', 18);
    await token.transfer(addr1.address, amount);
    await token.transfer(addr2.address, amount); // generates reflection for addr1
    const ONE = 10n ** 18n;
    async function claimable(addr) {
      const bal = await token.balanceOf(addr);
      const per = await token.reflectionPerToken();
      const credited = await token.reflectionCredited(addr);
      const stored = await token.reflectionBalance(addr);
      const calc = (bal * per) / ONE;
      const owed = calc > credited ? calc - credited : 0n;
      return stored + owed;
    }
    const before = await claimable(addr1.address);
    const burnAmt = (await token.balanceOf(addr1.address)) / 2n;
    await token.connect(addr1).burn(burnAmt);
    const after = await claimable(addr1.address);
    expect(after).to.equal(before);
  });

  it('never owes more reflections than it holds', async function () {
    const amount = ethers.parseUnits('1000', 18);
    await token.transfer(addr1.address, amount);
    await token.transfer(addr2.address, amount);

    const ONE = 10n ** 18n;
    async function claimable(addr) {
      const bal = await token.balanceOf(addr);
      const per = await token.reflectionPerToken();
      const credited = await token.reflectionCredited(addr);
      const stored = await token.reflectionBalance(addr);
      const calc = (bal * per) / ONE;
      const owed = calc > credited ? calc - credited : 0n;
      return stored + owed;
    }

    const addresses = [owner.address, addr1.address, addr2.address];
    let total = 0n;
    for (const a of addresses) {
      total += await claimable(a);
    }
    const contractBal = await token.balanceOf(token.target);
    expect(total).to.be.lte(contractBal);
  });

  it('only owner can set treasury', async function () {
    await expect(token.connect(addr1).setTreasury(addr2.address)).to.be
      .reverted;
    const Timelock = await ethers.getContractFactory('TimelockMock');
    const other = await Timelock.deploy(1);
    await other.waitForDeployment();
    await expect(token.setTreasury(other.target))
      .to.emit(token, 'TreasuryChanged')
      .withArgs(treasury.target, other.target);
    await expect(token.setTreasury(addr2.address)).to.be.reverted;
    const Token = await ethers.getContractFactory('GibsMeDatToken');
    await expect(Token.deploy(addr1.address)).to.be.revertedWith(
      'treasury not timelock'
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

  it('enforces configurable maximum total tax rate', async function () {
    await expect(token.setTaxRates(300, 300, 0)).to.be.revertedWith(
      'tax too high'
    );
    await expect(token.setTaxRates(200, 300, 0)).to.not.be.reverted;
    await expect(token.setMaxTotalTax(700)).to.not.be.reverted;
    await expect(token.setTaxRates(400, 300, 0)).to.not.be.reverted;
    await expect(token.setTaxRates(401, 300, 0)).to.be.revertedWith(
      'tax too high'
    );
    await expect(token.setMaxTotalTax(10001)).to.be.revertedWith(
      'max tax too high'
    );
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

  it('allows tax-exempt accounts to exceed max transfer amount', async function () {
    await token.setMaxTransferAmount(100n);
    await token.setTaxExempt(addr1.address, true);
    await expect(token.transfer(addr1.address, 101n)).to.not.be.reverted;

    await token.setTaxExempt(addr1.address, false);
    await token.setTaxExempt(owner.address, true);
    await expect(token.transfer(addr1.address, 101n)).to.not.be.reverted;
  });

  it('rescues tokens sent to the contract', async function () {
    await token.transfer(token.target, 100n);
    const before = await token.balanceOf(owner.address);
    await token.rescueTokens(token.target, owner.address, 100n);
    const after = await token.balanceOf(owner.address);
    expect(after - before).to.equal(100n);
  });

  it('rescues tokens without return value', async function () {
    const NoReturn = await ethers.getContractFactory('NoReturnERC20');
    const nr = await NoReturn.deploy();
    await nr.waitForDeployment();
    await nr.mint(token.target, 50n);
    await expect(token.rescueTokens(nr.target, owner.address, 50n))
      .to.emit(token, 'TokensRescued')
      .withArgs(nr.target, owner.address, 50n);
    expect(await nr.balanceOf(owner.address)).to.equal(50n);
  });

  it('reverts rescuing owed reflections', async function () {
    const amount = ethers.parseUnits('1000', 18);
    await token.transfer(addr1.address, amount);
    await expect(
      token.rescueTokens(token.target, owner.address, 1n)
    ).to.be.revertedWith('reflection owed');
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
