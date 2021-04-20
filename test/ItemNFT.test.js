const { assert } = require("chai");
const { advanceBlockTo } = require('@openzeppelin/test-helpers/src/time');
const { expectRevert, time } = require('@openzeppelin/test-helpers');
const ITemNFT = artifacts.require('ITemNFT');

contract('ITemNFT', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.itemNFT = await ITemNFT.new({ from: minter });
    });


    it('mint', async () => {
        await expectRevert(this.itemNFT.mintNft(alice,{ from: alice }), 'Ownable: caller is not the owner');
        await this.itemNFT.mintNft(alice, { from: minter });

        assert.equal((await this.itemNFT.balanceOf(alice)).toString(), '1');
    });

    it('burn', async () => {
        await this.itemNFT.mintNft(alice, { from: minter });


        assert.equal((await this.itemNFT.balanceOf(alice)).toString(), '1');

        await expectRevert(this.itemNFT.burnNft(1,{ from: alice }), 'Ownable: caller is not the owner');
        await expectRevert(this.itemNFT.burnNft(1,{ from: minter }), 'ERC721: transfer caller is not owner nor approved');
        
        await this.itemNFT.approve(minter, '1', { from: alice });

        await this.itemNFT.burnNft(1, { from: minter });
        assert.equal((await this.itemNFT.balanceOf(alice)).toString(), '0');


      });
});
