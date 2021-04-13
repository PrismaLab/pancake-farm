const { assert } = require("chai");

const PPXToken = artifacts.require('PPXToken');

contract('PPXToken', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.ppx = await PPXToken.new({ from: minter });
    });


    it('mint', async () => {
        await this.ppx.mint(alice, 1000, { from: minter });
        assert.equal((await this.ppx.balanceOf(alice)).toString(), '1000');
    });

});
