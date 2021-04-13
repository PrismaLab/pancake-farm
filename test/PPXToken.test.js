const { assert } = require("chai");
const { advanceBlockTo } = require('@openzeppelin/test-helpers/src/time');

const PPXToken = artifacts.require('PPXToken');

contract('PPXToken', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.ppx = await PPXToken.new({ from: minter });
    });


    it('mint', async () => {
        await this.ppx.mint(alice, 1000, { from: minter });
        assert.equal((await this.ppx.balanceOf(alice)).toString(), '1000');
    });

    it('burn', async () => {
        await advanceBlockTo('650');
        await this.ppx.mint(alice, 1000, { from: minter });
        await this.ppx.mint(bob, 1000, { from: minter });
        assert.equal((await this.ppx.totalSupply()).toString(), '2000');
        await this.ppx.burn(alice, 200, { from: minter });
    
        assert.equal((await this.ppx.balanceOf(alice)).toString(), '800');
        assert.equal((await this.ppx.totalSupply()).toString(), '1800');
      });
});
