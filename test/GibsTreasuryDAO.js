const { expect } = require('chai');
const { ethers } = require('hardhat');

const TOKEN_ID = 1;

describe('GibsTreasuryDAO', function () {
  let dao, redBook, gasGuzzler, owner;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    const RedBook = await ethers.getContractFactory('MockRedBook');
    redBook = await RedBook.deploy();
    await redBook.waitForDeployment();
    await redBook.mint(owner.address, TOKEN_ID, 1);

    const DAO = await ethers.getContractFactory('GibsTreasuryDAO');
    dao = await DAO.deploy(redBook.target);
    await dao.waitForDeployment();

    await owner.sendTransaction({
      to: dao.target,
      value: ethers.parseEther('1'),
    });

    const Guzzler = await ethers.getContractFactory('GasGuzzler');
    gasGuzzler = await Guzzler.deploy();
    await gasGuzzler.waitForDeployment();
  });

  it('executes proposal to contract needing more than 2300 gas', async function () {
    const amount = ethers.parseEther('0.1');
    await dao.propose(gasGuzzler.target, amount);
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
});
