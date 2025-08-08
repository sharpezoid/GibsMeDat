const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('MemeManifesto', function () {
  let owner, user2, user3, redBook, manifesto;

  beforeEach(async function () {
    [owner, user2, user3] = await ethers.getSigners();

    const RedBook = await ethers.getContractFactory('MockRedBook');
    redBook = await RedBook.deploy();
    await redBook.waitForDeployment();

    const Manifesto = await ethers.getContractFactory('MemeManifesto');
    manifesto = await Manifesto.deploy(redBook.target);
    await manifesto.waitForDeployment();

    // give Red Books to participants
    await redBook.mint(owner.address, 1, 1);
    await redBook.mint(user2.address, 1, 1);
    await redBook.mint(user3.address, 1, 1);
  });

  it('accepts pages and starts new chapters when full', async function () {
    for (let i = 0; i < 10; i++) {
      await expect(manifesto.connect(owner).proposePage('p' + i))
        .to.emit(manifesto, 'PageAdded')
        .withArgs(1n, BigInt(i + 1), owner.address, 'p' + i);
    }

    // next page should start chapter 2 at page 1
    await expect(manifesto.connect(owner).proposePage('next'))
      .to.emit(manifesto, 'PageAdded')
      .withArgs(2n, 1n, owner.address, 'next');
  });

  it('allows contributors to claim chapter NFTs', async function () {
    // owner and user2 contribute
    await manifesto.connect(owner).proposePage('owner page');
    await manifesto.connect(user2).proposePage('user2 page');

    // fill remaining pages by owner
    for (let i = 0; i < 8; i++) {
      await manifesto.connect(owner).proposePage('filler' + i);
    }

    // user3 did not contribute and should fail to claim
    await expect(manifesto.connect(user3).claimChapter(1)).to.be.revertedWith(
      'no contribution'
    );

    // contributors can claim once
    await expect(manifesto.connect(owner).claimChapter(1))
      .to.emit(manifesto, 'ChapterTokenClaimed')
      .withArgs(1n, owner.address, 1n);

    await expect(manifesto.connect(owner).claimChapter(1)).to.be.revertedWith(
      'already claimed'
    );

    await expect(manifesto.connect(user2).claimChapter(1))
      .to.emit(manifesto, 'ChapterTokenClaimed')
      .withArgs(1n, user2.address, 2n);
  });
});
