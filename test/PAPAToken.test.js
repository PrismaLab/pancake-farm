const { assert } = require("chai");

const PAPAToken = artifacts.require('PAPAToken');

contract('PAPAToken', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.ppx = await PAPAToken.new({ from: minter });
    });


    it('mint', async () => {
        await this.ppx.mint(alice, 1000, { from: minter });
        assert.equal((await this.ppx.balanceOf(alice)).toString(), '1000');
    });

});
