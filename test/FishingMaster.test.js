const { expectRevert, time } = require('@openzeppelin/test-helpers');
const YAYAToken = artifacts.require('YAYAToken');
const PAPAToken = artifacts.require('PAPAToken');
const ItemNFT = artifacts.require('ItemNFT');
const FishingMaster = artifacts.require('FishingMaster');
const ItemHelper = artifacts.require('ItemHelper');
const MockBEP20 = artifacts.require('libs/MockBEP20');

contract('FishingMaster', ([alice, bob, carol, dick, dev, minter]) => {
    beforeEach(async () => {
        this.ppx = await YAYAToken.new({ from: minter });
        this.ppy = await PAPAToken.new({ from: minter });
        this.ppe = await ItemNFT.new({ from: minter });
        this.itemHelper = await ItemHelper.new({ from: minter });
        this.lp1 = await MockBEP20.new('LPToken', 'LP1', '1000000', { from: minter });
        this.lp2 = await MockBEP20.new('LPToken', 'LP2', '1000000', { from: minter });
        this.lp3 = await MockBEP20.new('LPToken', 'LP3', '1000000', { from: minter });


        // For ppx spending tests
        await this.ppx.mint(carol, '580000000000000000000', { from: minter });
        await this.ppy.mint(dick, '100', { from: minter });


        this.chef = await FishingMaster.new(this.ppx.address, this.ppy.address, this.ppe.address, this.itemHelper.address, dev, '1000', '1000','100', { from: minter });
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
      assert.equal((await this.ppx.balanceOf(alice)).toString(), '350877192982456140350');

    })


    it('deposit/withdraw exp token', async () => {
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
      // 1000/3000 * 1000 * 4 = 1333.333.... 
      assert.equal((await this.ppx.balanceOf(alice)).toString(), '1333333333333333333332');
      // 1332 /10 
      assert.equal((await this.ppx.balanceOf(dev)).toString(), '133333333333333333332');
      
      await this.lp1.approve(this.chef.address, '100', { from: bob });
      assert.equal((await this.lp1.balanceOf(bob)).toString(), '2000');
      await this.chef.deposit(0, '50', { from: bob });
      assert.equal((await this.lp1.balanceOf(bob)).toString(), '1950');
      await this.chef.deposit(0, '0', { from: bob });
      // 1000/3000 * 1000 * (50/100) = 166
      assert.equal((await this.ppx.balanceOf(bob)).toString(), '166666666666666666666');
      await this.chef.emergencyWithdraw(0, { from: bob });
      assert.equal((await this.lp1.balanceOf(bob)).toString(), '2000');
    })

    it('deposit/withdraw main token', async () => {
        await this.chef.add('1000', this.lp1.address, false,true, { from: minter });
        await this.chef.add('1000', this.lp2.address, false,true, { from: minter });
        await this.chef.add('1000', this.lp3.address, false,true, { from: minter });
  
        await this.lp1.approve(this.chef.address, '100', { from: alice });
        await this.chef.deposit(0, '20', { from: alice });
        await this.chef.deposit(0, '0', { from: alice });
        await this.chef.deposit(0, '40', { from: alice });
        await this.chef.deposit(0, '0', { from: alice });
        assert.equal((await this.lp1.balanceOf(alice)).toString(), '1940');
        await this.chef.withdraw(0, '10', { from: alice });
        assert.equal((await this.lp1.balanceOf(alice)).toString(), '1950');
        // 1000/3000 * 1000 * 4 = 1333.333.... 
        assert.equal((await this.ppy.balanceOf(alice)).toString(), '1333333333333333333332');
        // 0
        assert.equal((await this.ppy.balanceOf(dev)).toString(), '0');
        
        await this.lp1.approve(this.chef.address, '100', { from: bob });
        assert.equal((await this.lp1.balanceOf(bob)).toString(), '2000');
        await this.chef.deposit(0, '50', { from: bob });
        assert.equal((await this.lp1.balanceOf(bob)).toString(), '1950');
        await this.chef.deposit(0, '0', { from: bob });
        // 1000/3000 * 1000 * (50/100) = 166
        assert.equal((await this.ppy.balanceOf(bob)).toString(), '166666666666666666666');
        await this.chef.emergencyWithdraw(0, { from: bob });
        assert.equal((await this.lp1.balanceOf(bob)).toString(), '2000');
      })

    it('staking papa/withdraw', async () => {
        await this.chef.add('1000', this.ppy.address, false,true, { from: minter });
        await this.chef.add('1000', this.lp2.address, false,true, { from: minter });
        await this.chef.add('1000', this.lp3.address, false,true, { from: minter });
  
        await this.ppy.approve(this.chef.address, '100', { from: dick });
        await this.chef.deposit(0, '20', { from: dick });
        await this.chef.deposit(0, '0', { from: dick });
        await this.chef.deposit(0, '40', { from: dick });
        await this.chef.deposit(0, '0', { from: dick });
        // 1000/3000 * 1000 *3 + ....40
        assert.equal((await this.ppy.balanceOf(dick)).toString(), '1000000000000000000039');
        await this.chef.withdraw(0, '10', { from: dick });
        // 1000/3000 * 1000 * 4 = 1333.333....  + ....50
        assert.equal((await this.ppy.balanceOf(dick)).toString(), '1333333333333333333382');
        // 0
        assert.equal((await this.ppy.balanceOf(dev)).toString(), '0');
        
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

      await this.chef.updateExpMultiplier('0', { from: minter });

      await this.chef.deposit(0, '0', { from: alice });
      await this.chef.deposit(0, '0', { from: bob });

      // 1000/3000 * (1 + 100/200 *2) = 666
      assert.equal((await this.ppx.balanceOf(alice)).toString(), '666666666666666666666');
      // 1000/3000 * (100/200 *2) = 333
      assert.equal((await this.ppx.balanceOf(bob)).toString(), '333333333333333333333');

      await time.advanceBlockTo('365');

      await this.chef.deposit(0, '0', { from: alice });
      await this.chef.deposit(0, '0', { from: bob });

      assert.equal((await this.ppx.balanceOf(alice)).toString(), '666666666666666666666');
      assert.equal((await this.ppx.balanceOf(bob)).toString(), '333333333333333333333');

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

    it('levelUp', async () => {
        await this.ppx.approve(this.chef.address, '580000000000000000000', { from: carol });

        assert.equal((await this.ppx.balanceOf(carol)).toString(), '580000000000000000000');
        assert.equal((await this.chef.getLevel(carol, { from: carol })).valueOf(), '0');
        assert.equal((await this.chef.getLevelUpExp(0, { from: carol })).valueOf(), '0');

        await this.chef.levelUp({ from: carol });

        assert.equal((await this.ppx.balanceOf(carol)).toString(), '580000000000000000000');
        assert.equal((await this.chef.getLevel(carol, { from: carol })).valueOf(), '1');
        assert.equal((await this.chef.getLevelUpExp(1, { from: carol })).valueOf(), '20000000000000000000');

        await this.chef.levelUp({ from: carol });

        assert.equal((await this.ppx.balanceOf(carol)).toString(), '560000000000000000000');
        assert.equal((await this.chef.getLevel(carol, { from: carol })).valueOf(), '2');
        assert.equal((await this.chef.getLevelUpExp(2, { from: carol })).valueOf(), '70000000000000000000');

        await this.chef.levelUp({ from: carol });

        assert.equal((await this.ppx.balanceOf(carol)).toString(), '490000000000000000000');
        assert.equal((await this.chef.getLevel(carol, { from: carol })).valueOf(), '3');
        assert.equal((await this.chef.getLevelUpExp(3, { from: carol })).valueOf(), '120000000000000000000');

        await this.chef.levelUp({ from: carol });

        assert.equal((await this.ppx.balanceOf(carol)).toString(), '370000000000000000000');
        assert.equal((await this.chef.getLevel(carol, { from: carol })).valueOf(), '4');
        assert.equal((await this.chef.getLevelUpExp(4, { from: carol })).valueOf(), '170000000000000000000');

        await this.chef.levelUp({ from: carol });

        assert.equal((await this.ppx.balanceOf(carol)).toString(), '200000000000000000000');
        assert.equal((await this.chef.getLevel(carol, { from: carol })).valueOf(), '5');
        assert.equal((await this.chef.getLevelUpExp(5, { from: carol })).valueOf(), '220000000000000000000');

        await expectRevert(this.chef.levelUp({ from: carol }), 'No enough balance.');
    })

});
