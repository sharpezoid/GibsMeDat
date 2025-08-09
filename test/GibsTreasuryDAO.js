const { expect } = require('chai');
const { ethers } = require('hardhat');

const TOKEN_ID = 1;

describe('GibsTreasuryDAO', function () {
  let dao, redBook, gasGuzzler, owner, other;

  beforeEach(async function () {
    [owner, other] = await ethers.getSigners();
    const RedBook = await ethers.getContractFactory('MockRedBook');
    redBook = await RedBook.deploy();
    await redBook.waitForDeployment();
    await redBook.mint(owner.address, TOKEN_ID, 1);

    const DAO = await ethers.getContractFactory('GibsTreasuryDAO');
    dao = await DAO.deploy(redBook.target, 1);
    await dao.waitForDeployment();

    await owner.sendTransaction({
      to: dao.target,
      value: ethers.parseEther('1'),
    });

    const Guzzler = await ethers.getContractFactory('GasGuzzler');
    gasGuzzler = await Guzzler.deploy();
    await gasGuzzler.waitForDeployment();
  });

  it('reverts when deploying with zero quorum', async function () {
    const DAO = await ethers.getContractFactory('GibsTreasuryDAO');
    await expect(DAO.deploy(redBook.target, 0)).to.be.revertedWith(
      'quorum zero'
    );
  });

  it('stores initial quorum', async function () {
    expect(await dao.quorum()).to.equal(1n);
  });

  it('reverts when setting quorum to zero', async function () {
    await expect(dao.setQuorum(0)).to.be.revertedWith('quorum zero');
  });

  it('executes proposal to contract needing more than 2300 gas', async function () {
    const amount = ethers.parseEther('0.1');
    await dao.propose(gasGuzzler.target, amount, '0x');
    const id = await dao.proposalCount();
    await dao.vote(id, true);

    await ethers.provider.send('evm_increaseTime', [3 * 24 * 60 * 60]);
    await ethers.provider.send('evm_mine');

    await expect(dao.execute(id)).to.emit(dao, 'Executed').withArgs(id, true);
    expect(await ethers.provider.getBalance(gasGuzzler.target)).to.equal(
      amount
    );
    expect(await gasGuzzler.gasLeft()).to.be.gt(2300n);
  });

  it('runs proposal lifecycle with majority support', async function () {
    const amount = ethers.parseEther('0.2');
    await dao.propose(gasGuzzler.target, amount, '0x');
    const id = await dao.proposalCount();
    await dao.vote(id, true);

    await ethers.provider.send('evm_increaseTime', [3 * 24 * 60 * 60]);
    await ethers.provider.send('evm_mine');

    const before = await ethers.provider.getBalance(gasGuzzler.target);
    await expect(dao.execute(id)).to.emit(dao, 'Executed').withArgs(id, true);
    const after = await ethers.provider.getBalance(gasGuzzler.target);
    expect(after - before).to.equal(amount);
  });

  it('fails when quorum not met', async function () {
    const amount = ethers.parseEther('0.05');
    await dao.setQuorum(2);
    await dao.propose(gasGuzzler.target, amount, '0x');
    const id = await dao.proposalCount();
    await dao.vote(id, true);

    await ethers.provider.send('evm_increaseTime', [3 * 24 * 60 * 60]);
    await ethers.provider.send('evm_mine');

    const before = await ethers.provider.getBalance(gasGuzzler.target);
    await expect(dao.execute(id)).to.emit(dao, 'Executed').withArgs(id, false);
    const after = await ethers.provider.getBalance(gasGuzzler.target);
    expect(after).to.equal(before);
  });

  it('passes when quorum met', async function () {
    const amount = ethers.parseEther('0.05');
    await dao.setQuorum(2);
    await redBook.mint(other.address, TOKEN_ID, 1);
    await dao.propose(gasGuzzler.target, amount, '0x');
    const id = await dao.proposalCount();
    await dao.vote(id, true);
    await dao.connect(other).vote(id, true);

    await ethers.provider.send('evm_increaseTime', [3 * 24 * 60 * 60]);
    await ethers.provider.send('evm_mine');

    const before = await ethers.provider.getBalance(gasGuzzler.target);
    await expect(dao.execute(id)).to.emit(dao, 'Executed').withArgs(id, true);
    const after = await ethers.provider.getBalance(gasGuzzler.target);
    expect(after - before).to.equal(amount);
  });
});
