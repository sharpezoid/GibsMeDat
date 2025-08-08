const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('MemeManifesto', function () {
  let owner, redBook, manifesto;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();
    const RedBook = await ethers.getContractFactory('MockRedBook');
    redBook = await RedBook.deploy();
    await redBook.waitForDeployment();

    const Manifesto = await ethers.getContractFactory('MemeManifesto');
    manifesto = await Manifesto.deploy(redBook.target);
    await manifesto.waitForDeployment();

    await redBook.mint(owner.address, 1, 1);
  });

  it('accepts pages up to maximum length', async function () {
    const maxLen = Number(await manifesto.MAX_PAGE_LENGTH());
    const text = 'a'.repeat(maxLen);
    await expect(manifesto.proposePage(text))
      .to.emit(manifesto, 'PageAdded')
      .withArgs(1n, owner.address, text);
  });

  it('rejects pages exceeding maximum length', async function () {
    const maxLen = Number(await manifesto.MAX_PAGE_LENGTH());
    const text = 'a'.repeat(maxLen + 1);
    await expect(manifesto.proposePage(text)).to.be.revertedWith(
      'page too long'
    );
  });
});
