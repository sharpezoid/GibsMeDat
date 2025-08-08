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

  it('enforces a maximum of 10 pages', async function () {
    for (let i = 0; i < 10; i++) {
      await expect(manifesto.proposePage('p' + i))
        .to.emit(manifesto, 'PageAdded')
        .withArgs(BigInt(i + 1), owner.address, 'p' + i);
    }
    await expect(manifesto.proposePage('extra')).to.be.revertedWith(
      'manifesto complete'
    );
  });

  it('allows ghost minting only after completion', async function () {
    await expect(
      manifesto.mintGhostOfMarx(owner.address)
    ).to.be.revertedWith('not enough pages');

    for (let i = 0; i < 10; i++) {
      await manifesto.proposePage('p' + i);
    }

    await expect(manifesto.mintGhostOfMarx(owner.address))
      .to.emit(manifesto, 'GhostOfMarxMinted')
      .withArgs(owner.address);

    await expect(
      manifesto.mintGhostOfMarx(owner.address)
    ).to.be.revertedWith('ghost summoned');
  });
});
