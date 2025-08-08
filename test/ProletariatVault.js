const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('ProletariatVault', function () {
  let token, vault, user;

  beforeEach(async function () {
    [, user] = await ethers.getSigners();
    const Token = await ethers.getContractFactory('FailingERC20');
    token = await Token.deploy();
    await token.waitForDeployment();
    const Vault = await ethers.getContractFactory('ProletariatVault');
    vault = await Vault.deploy(token.target);
    await vault.waitForDeployment();
  });

  it('allows staking and accrues yield over time', async function () {
    await token.mint(user.address, 100n);
    await token.connect(user).approve(vault.target, 100n);
    await expect(vault.connect(user).stake(1, 10n))
      .to.emit(vault, 'Staked')
      .withArgs(user.address, 1n, 10n);

    await ethers.provider.send('evm_increaseTime', [100]);
    await ethers.provider.send('evm_mine');

    await expect(vault.connect(user).unstake(1))
      .to.emit(vault, 'Unstaked')
      .withArgs(user.address, 1n, 10n, 1010n);
  });

  it('guards against reentrancy in stake and unstake', async function () {
    const Attacker = await ethers.getContractFactory('ReentrancyAttacker');
    const attacker = await Attacker.deploy(vault.target);
    await attacker.waitForDeployment();
    await token.mint(attacker.target, 100n);
    await attacker.approveToken(token.target, vault.target, 100n);
    await expect(attacker.attackStake(1, 10n)).to.be.revertedWith(
      'ReentrancyGuard: reentrant call'
    );
    await expect(attacker.attackUnstake(1, 10n)).to.be.revertedWith(
      'ReentrancyGuard: reentrant call'
    );
  });

  it('reverts when token transfer fails', async function () {
    await token.mint(user.address, 100n);
    await token.connect(user).approve(vault.target, 100n);
    await token.setShouldFail(true);
    await expect(vault.connect(user).stake(1, 10n)).to.be.revertedWith(
      'SafeERC20: ERC20 operation did not succeed'
    );
    await token.setShouldFail(false);
    await vault.connect(user).stake(1, 10n);
    await token.setShouldFail(true);
    await expect(vault.connect(user).unstake(1)).to.be.revertedWith(
      'SafeERC20: ERC20 operation did not succeed'
    );
  });
});
