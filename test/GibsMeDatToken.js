const { expect } = require("chai");
const { ethers } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

describe("GibsMeDatToken", function () {
  let owner, treasury, addr1, addr2, token;
  const DEAD = "0x000000000000000000000000000000000000dEaD";

  beforeEach(async function () {
    [owner, treasury, addr1, addr2] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("GibsMeDatToken");
    token = await Token.deploy(treasury.address);
    await token.waitForDeployment();
  });

  it("deploys with correct initial distribution and event", async function () {
    const total = await token.totalSupply();
    const expectedTotal = ethers.parseUnits("6942080085", 18);
    expect(total).to.equal(expectedTotal);

    const deadBal = await token.balanceOf(DEAD);
    const treasuryBal = await token.balanceOf(treasury.address);
    expect(deadBal).to.equal(expectedTotal * 10n / 100n);
    expect(treasuryBal).to.equal(expectedTotal * 5n / 100n);

    const deployTx = token.deploymentTransaction();
    await expect(deployTx)
      .to.emit(token, "LongLiveTheTokenomics")
      .withArgs(owner.address);
  });

  it("applies transfer tax and emits events", async function () {
    const amount = ethers.parseUnits("1000", 18);
    const treasuryInitial = await token.balanceOf(treasury.address);
    const deadInitial = await token.balanceOf(DEAD);
    const tx = await token.transfer(addr1.address, amount);
    const fee = amount * 69n / 10000n;
    const reflectionFee = amount * 30n / 10000n;
    const treasuryFee = amount * 30n / 10000n;
    const burnFee = amount * 9n / 10000n;

    await expect(tx).to.emit(token, "RedistributionOfWealth").withArgs(owner.address, fee);
    await expect(tx).to.emit(token, "GloriousContribution").withArgs(treasuryFee);
    await expect(tx).to.emit(token, "ToGulag").withArgs(burnFee);
    await expect(tx).to.emit(token, "ComradeReward").withArgs(reflectionFee);
    await expect(tx).to.emit(token, "HoardersPunished").withArgs(owner.address, fee);

    const received = await token.balanceOf(addr1.address);
    expect(received).to.equal(amount - fee);
    const treasuryDelta = (await token.balanceOf(treasury.address)) - treasuryInitial;
    expect(treasuryDelta).to.equal(treasuryFee);
    const deadDelta = (await token.balanceOf(DEAD)) - deadInitial;
    expect(deadDelta).to.equal(burnFee);
  });

  it("allows claiming reflections", async function () {
    const amount = ethers.parseUnits("1000", 18);
    await token.transfer(addr1.address, amount);
    await token.transfer(addr2.address, amount); // generates reflection for addr1
    const before = await token.balanceOf(addr1.address);
    const tx = await token.connect(addr1).claimReflection();
    await expect(tx).to.emit(token, "ReflectionClaimed").withArgs(addr1.address, anyValue);
    const after = await token.balanceOf(addr1.address);
    expect(after).to.be.gt(before);
  });

  it("only owner can set treasury", async function () {
    await expect(token.connect(addr1).setTreasury(addr2.address)).to.be.reverted;
    await expect(token.setTreasury(addr2.address))
      .to.emit(token, "TreasuryChanged")
      .withArgs(treasury.address, addr2.address);
  });
});
