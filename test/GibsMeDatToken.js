const { expect } = require("chai");
const { ethers } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("GibsMeDatToken", function () {
  let owner, team, treasury, faucet, addr1, addr2, token;
  const DEAD = "0x000000000000000000000000000000000000dEaD";

  beforeEach(async function () {
    [owner, team, treasury, faucet, addr1, addr2] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("GibsMeDatToken");
    token = await Token.deploy(team.address, treasury.address, faucet.address, owner.address);
    await token.waitForDeployment();
  });

  it("deploys with correct initial distribution and event", async function () {
    const total = await token.totalSupply();
    const expectedTotal = ethers.parseUnits("6942080085", 18);
    expect(total).to.equal(expectedTotal);

    const teamBal = await token.balanceOf(team.address);
    const treasuryBal = await token.balanceOf(treasury.address);
    const faucetBal = await token.balanceOf(faucet.address);
    const liquidityBal = await token.balanceOf(owner.address);
    const lockedBal = await token.balanceOf(await token.getAddress());
    expect(teamBal).to.equal(expectedTotal * 1n / 100n);
    expect(treasuryBal).to.equal(expectedTotal * 25n / 1000n);
    expect(faucetBal).to.equal(expectedTotal * 10n / 100n);
    expect(liquidityBal).to.equal(expectedTotal * 80n / 100n);
    expect(lockedBal).to.equal(expectedTotal * 65n / 1000n);

    const deployTx = token.deploymentTransaction();
    await expect(deployTx)
      .to.emit(token, "LongLiveTheTokenomics")
      .withArgs(owner.address);
  });

  it("applies transfer tax and emits events", async function () {
    const amount = ethers.parseUnits("1000", 18);
    const treasuryInitial = await token.balanceOf(treasury.address);
    const deadInitial = await token.balanceOf(DEAD);
    const tx = await token.connect(owner).transfer(addr1.address, amount);
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
    await token.connect(owner).transfer(addr1.address, amount);
    await token.connect(owner).transfer(addr2.address, amount); // generates reflection for addr1
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

  it("releases team tokens over time", async function () {
    await expect(token.releaseTeamTokens()).to.be.revertedWith("nothing to release");
    const initial = await token.balanceOf(team.address);
    const tranche = (await token.totalSupply()) * 65n / 1000n / 6n;
    await time.increase(90 * 24 * 60 * 60);
    await expect(token.releaseTeamTokens())
      .to.emit(token, "TeamTokensReleased")
      .withArgs(tranche);
    const after = await token.balanceOf(team.address);
    expect(after - initial).to.equal(tranche);
  });
});
