const { expectRevert, time } = require('@openzeppelin/test-helpers');
const PPXToken = artifacts.require('PPXToken');
const PPYToken = artifacts.require('PPYToken');
const EquipmentNFT = artifacts.require('EquipmentNFT');
const MasterChef = artifacts.require('MasterChef');
const MockBEP20 = artifacts.require('libs/MockBEP20');

contract('MasterChef', ([alice, bob, carol, dev, minter]) => {
    beforeEach(async () => {
        this.ppx = await PPXToken.new({ from: minter });
        this.ppy = await PPYToken.new({ from: minter });
        this.ppe = await EquipmentNFT.new({ from: minter });
        this.lp1 = await MockBEP20.new('LPToken', 'LP1', '1000000', { from: minter });
        this.lp2 = await MockBEP20.new('LPToken', 'LP2', '1000000', { from: minter });
        this.lp3 = await MockBEP20.new('LPToken', 'LP3', '1000000', { from: minter });
        this.chef = await MasterChef.new(this.ppx.address, this.ppy.address, this.ppe.address, dev, '1000', '100', { from: minter });
        await this.ppx.transferOwnership(this.chef.address, { from: minter });
        await this.ppy.transferOwnership(this.chef.address, { from: minter });
        await this.ppe.transferOwnership(this.chef.address, { from: minter });

        await this.lp1.transfer(bob, '2000', { from: minter });
        await this.lp2.transfer(bob, '2000', { from: minter });
        await this.lp3.transfer(bob, '2000', { from: minter });

        await this.lp1.transfer(alice, '2000', { from: minter });
        await this.lp2.transfer(alice, '2000', { from: minter });
        await this.lp3.transfer(alice, '2000', { from: minter });
    });
    it('real case', async () => {
      this.lp4 = await MockBEP20.new('LPToken', 'LP1', '1000000', { from: minter });
      this.lp5 = await MockBEP20.new('LPToken', 'LP2', '1000000', { from: minter });
      this.lp6 = await MockBEP20.new('LPToken', 'LP3', '1000000', { from: minter });
      this.lp7 = await MockBEP20.new('LPToken', 'LP1', '1000000', { from: minter });
      this.lp8 = await MockBEP20.new('LPToken', 'LP2', '1000000', { from: minter });
      this.lp9 = await MockBEP20.new('LPToken', 'LP3', '1000000', { from: minter });
      await this.chef.add('2000', this.lp1.address, true, true, { from: minter });
      await this.chef.add('1000', this.lp2.address, true, true, { from: minter });
      await this.chef.add('500', this.lp3.address, true, true, { from: minter });
      await this.chef.add('500', this.lp3.address, true, true, { from: minter });
      await this.chef.add('500', this.lp3.address, true, true, { from: minter });
      await this.chef.add('500', this.lp3.address, true, true, { from: minter });
      await this.chef.add('500', this.lp3.address, true, true, { from: minter });
      await this.chef.add('100', this.lp3.address, true, true, { from: minter });
      await this.chef.add('100', this.lp3.address, true, true, { from: minter });
      assert.equal((await this.chef.poolLength()).toString(), "9");

      await time.advanceBlockTo('170');
      await this.lp1.approve(this.chef.address, '1000', { from: alice });
      assert.equal((await this.ppx.balanceOf(alice)).toString(), '0');
      await this.chef.deposit(0, '20', { from: alice });
      await this.chef.withdraw(0, '20', { from: alice });
      // 2000/5700 * 1000 * 1 = 350.8
      assert.equal((await this.ppx.balanceOf(alice)).toString(), '350');

    })


    it('deposit/withdraw', async () => {
      await this.chef.add('1000', this.lp1.address, true,true, { from: minter });
      await this.chef.add('1000', this.lp2.address, true,true, { from: minter });
      await this.chef.add('1000', this.lp3.address, true,true, { from: minter });

      await this.lp1.approve(this.chef.address, '100', { from: alice });
      await this.chef.deposit(0, '20', { from: alice });
      await this.chef.deposit(0, '0', { from: alice });
      await this.chef.deposit(0, '40', { from: alice });
      await this.chef.deposit(0, '0', { from: alice });
      assert.equal((await this.lp1.balanceOf(alice)).toString(), '1940');
      await this.chef.withdraw(0, '10', { from: alice });
      assert.equal((await this.lp1.balanceOf(alice)).toString(), '1950');
      // 1000/3000 * 1000 * 4 = 1332 
      assert.equal((await this.ppx.balanceOf(alice)).toString(), '1332');
      // 1332 /10 
      assert.equal((await this.ppx.balanceOf(dev)).toString(), '132');
      
      await this.lp1.approve(this.chef.address, '100', { from: bob });
      assert.equal((await this.lp1.balanceOf(bob)).toString(), '2000');
      await this.chef.deposit(0, '50', { from: bob });
      assert.equal((await this.lp1.balanceOf(bob)).toString(), '1950');
      await this.chef.deposit(0, '0', { from: bob });
      // 1000/3000 * 1000 * (50/100) = 166
      assert.equal((await this.ppx.balanceOf(bob)).toString(), '166');
      await this.chef.emergencyWithdraw(0, { from: bob });
      assert.equal((await this.lp1.balanceOf(bob)).toString(), '2000');
    })

    
    it('update multiplier', async () => {
      await this.chef.add('1000', this.lp1.address,true, true, { from: minter });
      await this.chef.add('1000', this.lp2.address, true,true, { from: minter });
      await this.chef.add('1000', this.lp3.address,true, true, { from: minter });

      await this.lp1.approve(this.chef.address, '100', { from: alice });
      await this.lp1.approve(this.chef.address, '100', { from: bob });
      await this.chef.deposit(0, '100', { from: alice });
      await this.chef.deposit(0, '100', { from: bob });
      await this.chef.deposit(0, '0', { from: alice });
      await this.chef.deposit(0, '0', { from: bob });

      await this.ppx.approve(this.chef.address, '100', { from: alice });
      await this.ppx.approve(this.chef.address, '100', { from: bob });

      await this.chef.updateMultiplier('0', { from: minter });

      await this.chef.deposit(0, '0', { from: alice });
      await this.chef.deposit(0, '0', { from: bob });

      // 1000/3000 * (1 + 100/200 *2) = 666
      assert.equal((await this.ppx.balanceOf(alice)).toString(), '666');
      // 1000/3000 * (100/200 *2) = 333
      assert.equal((await this.ppx.balanceOf(bob)).toString(), '333');

      await time.advanceBlockTo('265');

      await this.chef.deposit(0, '0', { from: alice });
      await this.chef.deposit(0, '0', { from: bob });

      assert.equal((await this.ppx.balanceOf(alice)).toString(), '666');
      assert.equal((await this.ppx.balanceOf(bob)).toString(), '333');

      await this.chef.withdraw(0, '100', { from: alice });
      await this.chef.withdraw(0, '100', { from: bob });

    });

    it('should allow dev and only dev to update dev', async () => {
        assert.equal((await this.chef.devaddr()).valueOf(), dev);
        await expectRevert(this.chef.dev(bob, { from: bob }), 'dev: wut?');
        await this.chef.dev(bob, { from: dev });
        assert.equal((await this.chef.devaddr()).valueOf(), bob);
        await this.chef.dev(alice, { from: bob });
        assert.equal((await this.chef.devaddr()).valueOf(), alice);
    })

    it('genRandomNFT', async () => {
        await this.chef.add('1000', this.lp1.address,true, true, { from: minter });
      await this.chef.add('1000', this.lp2.address, true,true, { from: minter });
      await this.chef.add('1000', this.lp3.address,true, true, { from: minter });


        await this.chef.mintRandomNFT(alice, { from: minter });
        await this.chef.mintRandomNFT(alice, { from: minter });
        await this.chef.mintRandomNFT(alice, { from: minter });
        await this.chef.mintRandomNFT(alice, { from: minter });
        await this.chef.mintRandomNFT(alice, { from: minter });
       // let info = await this.chef.getNFTInfo(id).toString();
    })

});
