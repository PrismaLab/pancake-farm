const { BigNumber } = require("@ethersproject/bignumber");
const { expectRevert, time } = require("@openzeppelin/test-helpers");
const YAYAToken = artifacts.require("YAYAToken");
const PAPAToken = artifacts.require("PAPAToken");
const ItemNFT = artifacts.require("ItemNFT");
const FishingMaster = artifacts.require("FishingMaster");
const ItemHelper = artifacts.require("ItemHelper");
const MockBEP20 = artifacts.require("testlibs/MockBEP20");

contract("FishingMaster", ([alice, bob, carol, dick, eva, dev, treasury, minter]) => {
  beforeEach(async () => {
    this.ppx = await YAYAToken.new({ from: minter });
    this.ppy = await PAPAToken.new("1000000000000000000000000000", {
      from: minter,
    });
    this.ppe = await ItemNFT.new({ from: minter });
    this.itemHelper = await ItemHelper.new({ from: minter });
    this.lp1 = await MockBEP20.new("LPToken", "LP1", "1000000", {
      from: minter,
    });
    this.lp2 = await MockBEP20.new("LPToken", "LP2", "1000000", {
      from: minter,
    });
    this.lp3 = await MockBEP20.new("LPToken", "LP3", "1000000", {
      from: minter,
    });

    // For ppx spending tests
    await this.ppx.mint(carol, "580000000000000000000", { from: minter });
    await this.ppx.mint(eva, "160230000000000000000000", { from: minter });
    await this.ppy.mint(dick, "100", { from: minter });

    this.chef = await FishingMaster.new(
      this.ppx.address,
      this.ppy.address,
      this.ppe.address,
      this.itemHelper.address,
      dev,
      "1000",
      "1000",
      "100",
      { from: minter }
    );
    await this.ppx.transferOwnership(this.chef.address, { from: minter });
    await this.ppy.transferOwnership(this.chef.address, { from: minter });
    await this.ppe.transferOwnership(this.chef.address, { from: minter });

    await this.lp1.transfer(bob, "2000", { from: minter });
    await this.lp2.transfer(bob, "2000", { from: minter });
    await this.lp3.transfer(bob, "2000", { from: minter });

    await this.lp1.transfer(alice, "2000", { from: minter });
    await this.lp2.transfer(alice, "2000", { from: minter });
    await this.lp3.transfer(alice, "2000", { from: minter });
  });

  it("real case", async () => {
    this.lp4 = await MockBEP20.new("LPToken", "LP1", "1000000", {
      from: minter,
    });
    this.lp5 = await MockBEP20.new("LPToken", "LP2", "1000000", {
      from: minter,
    });
    this.lp6 = await MockBEP20.new("LPToken", "LP3", "1000000", {
      from: minter,
    });
    this.lp7 = await MockBEP20.new("LPToken", "LP1", "1000000", {
      from: minter,
    });
    this.lp8 = await MockBEP20.new("LPToken", "LP2", "1000000", {
      from: minter,
    });
    this.lp9 = await MockBEP20.new("LPToken", "LP3", "1000000", {
      from: minter,
    });
    await this.chef.add("1000", this.lp1.address, true, true, { from: minter });
    await this.chef.add("1000", this.lp2.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("100", this.lp3.address, true, true, { from: minter });
    await this.chef.add("100", this.lp3.address, true, true, { from: minter });
    assert.equal((await this.chef.poolLength()).toString(), "9");

    await this.chef.set(0, "2000", true, { from: minter });

    await time.advanceBlockTo("170");
    await this.lp1.approve(this.chef.address, "1000", { from: alice });
    assert.equal((await this.ppx.balanceOf(alice)).toString(), "0");

    await this.chef.deposit(0, "20", { from: alice });
    await time.advanceBlockTo("173");
    assert.equal(
      (await this.chef.pendingCake(0, { from: alice })).toString(),
      "350877192982456140350"
    );
    await this.chef.withdraw(0, "20", { from: alice });
    // 2000/5700 * 1000 * 2 = 701.75
    assert.equal(
      (await this.ppx.balanceOf(alice)).toString(),
      "701754385964912280701"
    );

    // a long time
    await this.chef.updateLockPeriod(1000000000, { from: minter });
    // half
    await this.chef.updateLockPenalty(500000, { from: minter });

    await this.chef.setTreasury(treasury, { from: minter });

    await this.chef.deposit(0, "20", { from: alice });
    await this.chef.withdraw(0, "20", { from: alice });
    assert.equal((await this.lp1.balanceOf(alice)).toString(), "1990");
    assert.equal((await this.lp1.balanceOf(treasury)).toString(), "10");

  });

  it("deposit/withdraw exp token", async () => {
    await this.chef.add("2000", this.lp1.address, true, true, { from: minter });
    await this.chef.add("1000", this.lp2.address, true, true, { from: minter });
    await this.chef.add("1000", this.lp3.address, true, true, { from: minter });

    await this.chef.set(0, "1000", true, { from: minter });

    await this.chef.unlockItemSlot({ from: alice });
    await this.chef.mintNFT(alice, 0, 0, [1, 2, 3, 4, 0, 0], { from: minter });

    await this.chef.equipNFT(0, 1, { from: alice });

    await this.chef.updateNFTDropRate("3", "1", "40000", { from: minter });

    await this.lp1.approve(this.chef.address, "100", { from: alice });
    await this.chef.deposit(0, "20", { from: alice });
    assert.equal(
      (await this.chef.getNFTDropRate(0, { from: alice })).toString(),
      "0"
    );
    await this.chef.deposit(0, "0", { from: alice });
    await this.chef.deposit(0, "40", { from: alice });
    await this.chef.deposit(0, "0", { from: alice });
    assert.equal(
      (await this.chef.getNFTDropRate(0, { from: alice })).toString(),
      "0"
    );
    assert.equal((await this.lp1.balanceOf(alice)).toString(), "1940");
    await this.chef.withdraw(0, "10", { from: alice });
    assert.equal((await this.lp1.balanceOf(alice)).toString(), "1950");
    // 1000/3000 * 1000 * 4 = 1333.333....
    assert.equal(
      (await this.ppx.balanceOf(alice)).toString(),
      "1333333333333333333332"
    );
    // 1332 /10
    assert.equal(
      (await this.ppx.balanceOf(dev)).toString(),
      "133333333333333333332"
    );

    await this.lp1.approve(this.chef.address, "100", { from: bob });
    assert.equal((await this.lp1.balanceOf(bob)).toString(), "2000");
    await this.chef.deposit(0, "50", { from: bob });
    assert.equal((await this.lp1.balanceOf(bob)).toString(), "1950");
    await this.chef.deposit(0, "0", { from: bob });
    // 1000/3000 * 1000 * (50/100) = 166
    assert.equal(
      (await this.ppx.balanceOf(bob)).toString(),
      "166666666666666666666"
    );
    await this.chef.emergencyWithdraw(0, { from: bob });
    assert.equal((await this.lp1.balanceOf(bob)).toString(), "2000");
  });

  it("deposit/withdraw main token", async () => {
    await this.chef.add("2000", this.lp1.address, false, true, {
      from: minter,
    });
    await this.chef.add("1000", this.lp2.address, false, true, {
      from: minter,
    });
    await this.chef.add("1000", this.lp3.address, false, true, {
      from: minter,
    });

    await this.chef.set(0, "1000", true, { from: minter });

    await this.chef.unlockItemSlot({ from: alice });
    await this.chef.mintNFT(alice, 0, 0, [1, 2, 3, 0, 0, 0], { from: minter });

    await this.chef.equipNFT(0, 1, { from: alice });

    await this.chef.updateNFTDropRate("3", "1", "40000", { from: minter });

    await this.lp1.approve(this.chef.address, "100", { from: alice });
    await this.chef.deposit(0, "20", { from: alice });
    assert.equal(
      (await this.chef.getNFTDropRate(0, { from: alice })).valueOf().toString(),
      "0"
    );
    await this.chef.deposit(0, "0", { from: alice });
    await this.chef.deposit(0, "40", { from: alice });
    await this.chef.deposit(0, "0", { from: alice });
    assert.equal(
      (await this.chef.getNFTDropRate(0, { from: alice })).valueOf().toString(),
      "0"
    );
    assert.equal((await this.lp1.balanceOf(alice)).toString(), "1940");
    await this.chef.withdraw(0, "10", { from: alice });
    assert.equal((await this.lp1.balanceOf(alice)).toString(), "1950");
    // 1000/3000 * 1000 * 4 = 1333.333....
    assert.equal(
      (await this.ppy.balanceOf(alice)).toString(),
      "1333333333333333333332"
    );
    // 0
    assert.equal((await this.ppy.balanceOf(dev)).toString(), "0");

    await this.lp1.approve(this.chef.address, "100", { from: bob });
    assert.equal((await this.lp1.balanceOf(bob)).toString(), "2000");
    await this.chef.deposit(0, "50", { from: bob });
    assert.equal((await this.lp1.balanceOf(bob)).toString(), "1950");
    await this.chef.deposit(0, "0", { from: bob });
    // 1000/3000 * 1000 * (50/100) = 166
    assert.equal(
      (await this.ppy.balanceOf(bob)).toString(),
      "166666666666666666666"
    );
    await this.chef.emergencyWithdraw(0, { from: bob });
    assert.equal((await this.lp1.balanceOf(bob)).toString(), "2000");
  });

  it("staking papa/withdraw", async () => {
    await this.chef.add("1000", this.ppy.address, false, true, {
      from: minter,
    });
    await this.chef.add("1000", this.lp2.address, false, true, {
      from: minter,
    });
    await this.chef.add("1000", this.lp3.address, false, true, {
      from: minter,
    });

    await this.ppy.approve(this.chef.address, "100", { from: dick });
    await this.chef.deposit(0, "20", { from: dick });
    await this.chef.deposit(0, "0", { from: dick });
    await this.chef.deposit(0, "40", { from: dick });
    await this.chef.deposit(0, "0", { from: dick });
    // 1000/3000 * 1000 *3 + ....40
    assert.equal(
      (await this.ppy.balanceOf(dick)).toString(),
      "1000000000000000000039"
    );
    await this.chef.withdraw(0, "10", { from: dick });
    // 1000/3000 * 1000 * 4 = 1333.333....  + ....50
    assert.equal(
      (await this.ppy.balanceOf(dick)).toString(),
      "1333333333333333333382"
    );
    // 0
    assert.equal((await this.ppy.balanceOf(dev)).toString(), "0");
  });

  it("update multiplier", async () => {
    await this.chef.add("1000", this.lp1.address, true, true, { from: minter });
    await this.chef.add("1000", this.lp2.address, true, true, { from: minter });
    await this.chef.add("1000", this.lp3.address, true, true, { from: minter });

    await this.lp1.approve(this.chef.address, "100", { from: alice });
    await this.lp1.approve(this.chef.address, "100", { from: bob });
    await this.chef.deposit(0, "100", { from: alice });
    await this.chef.deposit(0, "100", { from: bob });
    await this.chef.deposit(0, "0", { from: alice });
    await this.chef.deposit(0, "0", { from: bob });

    await this.ppx.approve(this.chef.address, "100", { from: alice });
    await this.ppx.approve(this.chef.address, "100", { from: bob });

    await this.chef.updateExpMultiplier("0", { from: minter });

    await this.chef.deposit(0, "0", { from: alice });
    await this.chef.deposit(0, "0", { from: bob });

    // 1000/3000 * (1 + 100/200 *2) = 666
    assert.equal(
      (await this.ppx.balanceOf(alice)).toString(),
      "666666666666666666666"
    );
    // 1000/3000 * (100/200 *2) = 333
    assert.equal(
      (await this.ppx.balanceOf(bob)).toString(),
      "333333333333333333333"
    );

    await time.advanceBlockTo("365");

    await this.chef.deposit(0, "0", { from: alice });
    await this.chef.deposit(0, "0", { from: bob });

    assert.equal(
      (await this.ppx.balanceOf(alice)).toString(),
      "666666666666666666666"
    );
    assert.equal(
      (await this.ppx.balanceOf(bob)).toString(),
      "333333333333333333333"
    );

    await this.chef.withdraw(0, "100", { from: alice });
    await this.chef.withdraw(0, "100", { from: bob });
  });

  it("should allow dev and only dev to update dev", async () => {
    assert.equal((await this.chef.devaddr()).valueOf(), dev);
    await expectRevert(this.chef.dev(bob, { from: bob }), "dev: wut?");
    await this.chef.dev(bob, { from: dev });
    assert.equal((await this.chef.devaddr()).valueOf(), bob);
    await this.chef.dev(alice, { from: bob });
    assert.equal((await this.chef.devaddr()).valueOf(), alice);
  });

  it("NFTTest", async () => {
    await this.chef.add("1000", this.lp1.address, true, true, { from: minter });
    await this.chef.add("1000", this.lp2.address, true, true, { from: minter });
    await this.chef.add("1000", this.lp3.address, true, true, { from: minter });

    // Mint
    await this.chef.mintRandomNFT(carol, { from: minter }); // 1
    await this.chef.mintNFT(carol, 0, 0, [0, 0, 0, 0, 0, 0], { from: minter }); // 2
    await this.chef.mintNFT(carol, 0, 0, [0, 0, 0, 0, 0, 0], { from: minter }); // 3

    assert.equal(
      (await this.ppe.ownerOf(1, { from: minter })).valueOf(),
      carol
    );
    assert.equal(
      (await this.ppe.ownerOf(2, { from: minter })).valueOf(),
      carol
    );
    assert.equal(
      (await this.ppe.ownerOf(3, { from: minter })).valueOf(),
      carol
    );

    // Equip slot

    assert.equal(
      (await this.chef.getInvSlotNum({ from: carol })).valueOf(),
      "0"
    );
    await this.chef.unlockItemSlot({ from: carol });
    assert.equal(
      (await this.chef.getInvSlotNum({ from: carol })).valueOf(),
      "1"
    );

    // Equip

    let inv = await this.chef.getInventory({ from: carol }).valueOf();
    assert.equal(inv[0], 0);
    assert.equal(inv[1], 0);
    assert.equal(inv[2], 0);
    assert.equal(inv[3], 0);
    assert.equal(inv[4], 0);
    assert.equal(inv[5], 0);

    await expectRevert(
      this.chef.equipNFT(0, 1, { from: carol }),
      "no enough level"
    );

    await this.chef.equipNFT(0, 2, { from: carol });
    inv = await this.chef.getInventory({ from: carol }).valueOf();
    assert.equal(inv[0], 2);
    assert.equal(inv[1], 0);
    assert.equal(inv[2], 0);
    assert.equal(inv[3], 0);
    assert.equal(inv[4], 0);
    assert.equal(inv[5], 0);

    await expectRevert(
      this.chef.equipNFT(0, 2, { from: carol }),
      "already equipped"
    );

    await this.chef.equipNFT(0, 0, { from: carol });
    inv = await this.chef.getInventory({ from: carol }).valueOf();
    assert.equal(inv[0], 0);
    assert.equal(inv[1], 0);
    assert.equal(inv[2], 0);
    assert.equal(inv[3], 0);
    assert.equal(inv[4], 0);
    assert.equal(inv[5], 0);

    await expectRevert(
      this.chef.equipNFT(1, 2, { from: carol }),
      "invalid slot"
    );
    await expectRevert(
      this.chef.equipNFT(0, 0, { from: carol }),
      "already empty"
    );

    await this.chef.mintRandomNFT(alice, { from: minter }); // 4
    await expectRevert(
      this.chef.equipNFT(0, 4, { from: carol }),
      "not item owner"
    );

    // Reforge

    await this.ppe.approve(this.chef.address, "1", { from: carol });
    await this.ppe.approve(this.chef.address, "2", { from: carol });
    await this.ppe.approve(this.chef.address, "3", { from: carol });

    await this.chef.equipNFT(0, 2, { from: carol });

    await expectRevert(
      this.chef.reforgeNFT(1, 2, 3, { from: carol }),
      "Item in use!"
    );
    await expectRevert(
      this.chef.reforgeNFT(3, 1, 2, { from: carol }),
      "Item in use!"
    );
    await expectRevert(
      this.chef.reforgeNFT(2, 3, 1, { from: carol }),
      "Item in use!"
    );

    await expectRevert(
      this.chef.reforgeNFT(1, 4, 3, { from: carol }),
      "Not owner!"
    );
    await expectRevert(
      this.chef.reforgeNFT(3, 1, 4, { from: carol }),
      "Not owner!"
    );
    await expectRevert(
      this.chef.reforgeNFT(4, 3, 1, { from: carol }),
      "Not owner!"
    );

    await this.chef.equipNFT(0, 0, { from: carol });

    await this.chef.reforgeNFT(1, 3, 2, { from: carol }); // to 5

    assert.equal(
      (await this.ppe.ownerOf(5, { from: minter })).valueOf(),
      carol
    );

    // buy/reroll
    await this.ppx.approve(this.chef.address, "580000000000000000000", {
      from: carol,
    });

    await expectRevert(
      this.chef.buyRandomNFT({ from: carol }),
      "Buying NFT not enabled."
    );

    await this.chef.updateRandomNftPrice("590000000000000000000", {
      from: minter,
    });
    assert.equal(
      (await this.chef.RANDOM_NFT_PRICE()).toString(),
      "590000000000000000000"
    );

    await expectRevert(
      this.chef.buyRandomNFT({ from: carol }),
      "No enough balance."
    );

    await this.chef.updateRandomNftPrice("80000000000000000000", {
      from: minter,
    });
    assert.equal(
      (await this.chef.RANDOM_NFT_PRICE()).toString(),
      "80000000000000000000"
    );

    await this.chef.buyRandomNFT({ from: carol }); // to 6

    assert.equal(
      (await this.ppx.balanceOf(carol)).toString(),
      "500000000000000000000"
    );

    await expectRevert(
      this.chef.upgradeNFT(6, 0, { from: carol }),
      "Upgrading NFT not enabled."
    );

    await this.chef.updateUpgradeNftPrice("590000000000000000000", {
      from: minter,
    });
    assert.equal(
      (await this.chef.UPGRADE_NFT_PRICE()).toString(),
      "590000000000000000000"
    );

    await expectRevert(
      this.chef.upgradeNFT(6, 0, { from: carol }),
      "No enough balance."
    );

    await this.chef.updateUpgradeNftPrice("100000000000000000000", {
      from: minter,
    });
    assert.equal(
      (await this.chef.UPGRADE_NFT_PRICE()).toString(),
      "100000000000000000000"
    );

    await expectRevert(
      this.chef.upgradeNFT(4, 0, { from: carol }),
      "Not owner!"
    );

    await this.chef.mintNFT(carol, 0, 0, [1, 2, 3, 4, 0, 0], { from: minter }); // 7

    await this.chef.equipNFT(0, 7, { from: carol });
    await expectRevert(
      this.chef.upgradeNFT(7, 0, { from: carol }),
      "Item in use!"
    );
    await this.chef.equipNFT(0, 0, { from: carol });
    await expectRevert(
      this.chef.upgradeNFT(7, 7, { from: carol }),
      "index out of range!"
    );
    await expectRevert(
      this.chef.upgradeNFT(7, 4, { from: carol }),
      "No existing attr!"
    );

    this.chef.upgradeNFT(7, 0, { from: carol });

    assert.equal(
      (await this.ppx.balanceOf(carol)).toString(),
      "400000000000000000000"
    );

    this.chef.upgradeNFT(7, 1, { from: carol });

    assert.equal(
      (await this.ppx.balanceOf(carol)).toString(),
      "300000000000000000000"
    );

    this.chef.upgradeNFT(7, 2, { from: carol });

    assert.equal(
      (await this.ppx.balanceOf(carol)).toString(),
      "200000000000000000000"
    );

    this.chef.upgradeNFT(7, 3, { from: carol });

    assert.equal(
      (await this.ppx.balanceOf(carol)).toString(),
      "100000000000000000000"
    );

    await this.chef.mintNFT(carol, 5, 6, [1, 2, 3, 1, 2, 3], { from: minter }); // 8

    let info = await this.chef.getNFTInfo(8, { from: carol });
    assert.equal(info.level, "5");
    assert.equal(info.template, "6");
    assert.equal(info.attr[0], "1");
    assert.equal(info.attr[1], "2");
    assert.equal(info.attr[2], "3");
    assert.equal(info.attr[3], "1");
    assert.equal(info.attr[4], "2");
    assert.equal(info.attr[5], "3");
  });

  it("levelUpAndUnlockSlot", async () => {
    let balance = BigNumber.from((await this.ppx.balanceOf(eva)).toString());

    await this.ppx.approve(this.chef.address, balance.toString(), {
      from: eva,
    });

    // zero is special
    assert.equal((await this.chef.getLevel({ from: eva })).valueOf(), "0");
    assert.equal(
      (await this.chef.getLevelUpExp(0, { from: eva })).valueOf(),
      "0"
    );
    await this.chef.levelUp({ from: eva });
    await this.chef.unlockItemSlot({ from: eva });
    assert.equal((await this.chef.getInvSlotNum({ from: eva })).valueOf(), "1");
    assert.equal(
      (await this.ppx.balanceOf(eva)).toString(),
      balance.toString()
    );

    for (level = 1; level < 62; level++) {
      if (level == 20) {
        await expectRevert(
          this.chef.unlockItemSlot({ from: eva }),
          "No enough level."
        );
        assert.equal(
          (
            await this.chef.getUnlockSlotLevelRequirement(1, { from: eva })
          ).valueOf(),
          "21"
        );
      } else if (level == 21) {
        let cost = BigNumber.from(
          (await this.chef.getUnlockSlotExp(1, { from: eva })).toString()
        );
        balance = balance.sub(cost);
        await this.chef.unlockItemSlot({ from: eva });
        assert.equal(
          (await this.chef.getInvSlotNum({ from: eva })).valueOf(),
          "2"
        );
      } else if (level == 30) {
        await expectRevert(
          this.chef.unlockItemSlot({ from: eva }),
          "No enough level."
        );
        assert.equal(
          (
            await this.chef.getUnlockSlotLevelRequirement(2, { from: eva })
          ).valueOf(),
          "31"
        );
      } else if (level == 31) {
        let cost = BigNumber.from(
          (await this.chef.getUnlockSlotExp(2, { from: eva })).toString()
        );
        balance = balance.sub(cost);
        await this.chef.unlockItemSlot({ from: eva });
        assert.equal(
          (await this.chef.getInvSlotNum({ from: eva })).valueOf(),
          "3"
        );
      } else if (level == 40) {
        await expectRevert(
          this.chef.unlockItemSlot({ from: eva }),
          "No enough level."
        );
        assert.equal(
          (
            await this.chef.getUnlockSlotLevelRequirement(3, { from: eva })
          ).valueOf(),
          "41"
        );
      } else if (level == 41) {
        let cost = BigNumber.from(
          (await this.chef.getUnlockSlotExp(3, { from: eva })).toString()
        );
        balance = balance.sub(cost);
        await this.chef.unlockItemSlot({ from: eva });
        assert.equal(
          (await this.chef.getInvSlotNum({ from: eva })).valueOf(),
          "4"
        );
      } else if (level == 50) {
        await expectRevert(
          this.chef.unlockItemSlot({ from: eva }),
          "No enough level."
        );
        assert.equal(
          (
            await this.chef.getUnlockSlotLevelRequirement(4, { from: eva })
          ).valueOf(),
          "51"
        );
      } else if (level == 51) {
        let cost = BigNumber.from(
          (await this.chef.getUnlockSlotExp(4, { from: eva })).toString()
        );
        balance = balance.sub(cost);
        await this.chef.unlockItemSlot({ from: eva });
        assert.equal(
          (await this.chef.getInvSlotNum({ from: eva })).valueOf(),
          "5"
        );
      } else if (level == 60) {
        await expectRevert(
          this.chef.unlockItemSlot({ from: eva }),
          "No enough level."
        );
        assert.equal(
          (
            await this.chef.getUnlockSlotLevelRequirement(5, { from: eva })
          ).valueOf(),
          "61"
        );
      } else if (level == 61) {
        let cost = BigNumber.from(
          (await this.chef.getUnlockSlotExp(5, { from: eva })).toString()
        );
        balance = balance.sub(cost);
        await this.chef.unlockItemSlot({ from: eva });
        assert.equal(
          (await this.chef.getInvSlotNum({ from: eva })).valueOf(),
          "6"
        );
      }

      let expected_exp = BigNumber.from(level * 50 - 30).mul(
        "1000000000000000000"
      );
      assert.equal(
        (await this.chef.getLevel({ from: eva })).valueOf(),
        level.toString()
      );
      assert.equal(
        (await this.chef.getLevelUpExp(level, { from: eva }))
          .valueOf()
          .toString(),
        expected_exp.toString()
      );
      assert(
        balance.gt(expected_exp),
        balance.toString() + "!>" + expected_exp.toString()
      );
      await this.chef.levelUp({ from: eva });
      balance = balance.sub(expected_exp);
      assert.equal(
        (await this.ppx.balanceOf(eva)).toString(),
        balance.toString()
      );
    }

    await expectRevert(
      this.chef.unlockItemSlot({ from: eva }),
      "Maximum slot unlocked."
    );
    await expectRevert(this.chef.levelUp({ from: eva }), "No enough balance.");

    // return 0 for invalid input, avoid exception in view
    assert.equal(
      (await this.chef.getUnlockSlotExp(6, { from: eva })).valueOf(),
      "0"
    );
    assert.equal(
      (
        await this.chef.getUnlockSlotLevelRequirement(6, { from: eva })
      ).valueOf(),
      "0"
    );

    // Some high level equip test
    await this.chef.mintNFT(eva, 0, 0, [0, 0, 0, 0, 0, 0], { from: minter }); // 1
    await this.chef.mintNFT(eva, 0, 0, [0, 0, 0, 0, 0, 0], { from: minter }); // 2
    await this.chef.mintNFT(eva, 0, 0, [0, 0, 0, 0, 0, 0], { from: minter }); // 3
    await this.chef.mintNFT(eva, 0, 0, [0, 0, 0, 0, 0, 0], { from: minter }); // 4
    await this.chef.equipNFT(3, 1, { from: eva });
    await this.chef.equipNFT(3, 4, { from: eva });

    await this.ppe.approve(this.chef.address, "1", { from: eva });
    await this.ppe.approve(this.chef.address, "2", { from: eva });
    await this.ppe.approve(this.chef.address, "3", { from: eva });
    await this.ppe.approve(this.chef.address, "4", { from: eva });

    await expectRevert(
      this.chef.reforgeNFT(1, 2, 4, { from: eva }),
      "Item in use!"
    );
    await this.chef.reforgeNFT(1, 2, 3, { from: eva }); // to 5
  });

  it("update modifiers and user info", async () => {
    // updateExpMultiplier
    assert.equal(
      (await this.chef.EXP_BONUS_MULTIPLIER()).valueOf(),
      "1000000000000000000"
    );
    await expectRevert(
      this.chef.updateExpMultiplier("2000000000000000000", { from: alice }),
      "Ownable: caller is not the owner"
    );
    await this.chef.updateExpMultiplier("2000000000000000000", {
      from: minter,
    });
    assert.equal(
      (await this.chef.EXP_BONUS_MULTIPLIER()).valueOf(),
      "2000000000000000000"
    );
    await this.chef.updateExpMultiplier("1000000000000000000", {
      from: minter,
    });
    assert.equal(
      (await this.chef.EXP_BONUS_MULTIPLIER()).valueOf(),
      "1000000000000000000"
    );

    // updateMainMultiplier
    assert.equal(
      (await this.chef.MAIN_BONUS_MULTIPLIER()).valueOf(),
      "1000000000000000000"
    );
    await expectRevert(
      this.chef.updateMainMultiplier("2000000000000000000", { from: alice }),
      "Ownable: caller is not the owner"
    );
    await this.chef.updateMainMultiplier("2000000000000000000", {
      from: minter,
    });
    assert.equal(
      (await this.chef.MAIN_BONUS_MULTIPLIER()).valueOf(),
      "2000000000000000000"
    );
    await this.chef.updateMainMultiplier("1000000000000000000", {
      from: minter,
    });
    assert.equal(
      (await this.chef.MAIN_BONUS_MULTIPLIER()).valueOf(),
      "1000000000000000000"
    );

    // updateMaxLevel
    assert.equal((await this.chef.MAX_LEVEL()).valueOf(), "20");
    await expectRevert(
      this.chef.updateMaxLevel("10", { from: alice }),
      "Ownable: caller is not the owner"
    );
    await this.chef.updateMaxLevel("10", { from: minter });
    assert.equal((await this.chef.MAX_LEVEL()).valueOf(), "10");
    await this.chef.updateMaxLevel("20", { from: minter });
    assert.equal((await this.chef.MAX_LEVEL()).valueOf(), "20");

    // updateRandomNftPrice
    assert.equal((await this.chef.RANDOM_NFT_PRICE()).valueOf(), "0");
    await expectRevert(
      this.chef.updateRandomNftPrice("10", { from: alice }),
      "Ownable: caller is not the owner"
    );
    await this.chef.updateRandomNftPrice("10", { from: minter });
    assert.equal((await this.chef.RANDOM_NFT_PRICE()).valueOf(), "10");
    await this.chef.updateRandomNftPrice("0", { from: minter });
    assert.equal((await this.chef.RANDOM_NFT_PRICE()).valueOf(), "0");

    // updateUpgradeNftPrice
    assert.equal((await this.chef.UPGRADE_NFT_PRICE()).valueOf(), "0");
    await expectRevert(
      this.chef.updateUpgradeNftPrice("10", { from: alice }),
      "Ownable: caller is not the owner"
    );
    await this.chef.updateUpgradeNftPrice("10", { from: minter });
    assert.equal((await this.chef.UPGRADE_NFT_PRICE()).valueOf(), "10");
    await this.chef.updateUpgradeNftPrice("0", { from: minter });
    assert.equal((await this.chef.UPGRADE_NFT_PRICE()).valueOf(), "0");

    // updateNFTDropRate

    assert.equal((await this.chef.NFT_BASE_DROP_RATE_INC()).valueOf(), "2");
    assert.equal(
      (await this.chef.NFT_BASE_DROP_RATE_BASE()).valueOf(),
      "1000000"
    );
    assert.equal((await this.chef.NFT_DROP_RATE_CAP()).valueOf(), "20000");
    await expectRevert(
      this.chef.updateNFTDropRate("3", "3000000", "40000", { from: alice }),
      "Ownable: caller is not the owner"
    );
    await this.chef.updateNFTDropRate("3", "3000000", "40000", {
      from: minter,
    });
    assert.equal((await this.chef.NFT_BASE_DROP_RATE_INC()).valueOf(), "3");
    assert.equal(
      (await this.chef.NFT_BASE_DROP_RATE_BASE()).valueOf(),
      "3000000"
    );
    assert.equal((await this.chef.NFT_DROP_RATE_CAP()).valueOf(), "40000");
    await this.chef.updateNFTDropRate("2", "1000000", "20000", {
      from: minter,
    });
    assert.equal((await this.chef.NFT_BASE_DROP_RATE_INC()).valueOf(), "2");
    assert.equal(
      (await this.chef.NFT_BASE_DROP_RATE_BASE()).valueOf(),
      "1000000"
    );
    assert.equal((await this.chef.NFT_DROP_RATE_CAP()).valueOf(), "20000");

    // updateCustomizeInfo
    assert.equal(
      (await this.chef.getCustomizeInfo({ from: alice })).valueOf(),
      "0"
    );
    await this.chef.updateCustomizeInfo("2000000000000000000", { from: alice });
    assert.equal(
      (await this.chef.getCustomizeInfo()).valueOf(),
      "2000000000000000000"
    );
    await this.chef.updateCustomizeInfo("1000000000000000000", { from: alice });
    assert.equal(
      (await this.chef.getCustomizeInfo()).valueOf(),
      "1000000000000000000"
    );

    // updateLockPeriod
    assert.equal(
        (await this.chef.LOCK_PERIOD({ from: alice })).valueOf(),
        "0"
      );
      await expectRevert(
        this.chef.updateLockPeriod("10", { from: alice }),
        "Ownable: caller is not the owner"
      );
      await this.chef.updateLockPeriod("2000000000000000000", { from: minter });
      assert.equal(
        (await this.chef.LOCK_PERIOD()).valueOf(),
        "2000000000000000000"
      );
      await this.chef.updateLockPeriod("1000000000000000000", { from: minter });
      assert.equal(
        (await this.chef.LOCK_PERIOD()).valueOf(),
        "1000000000000000000"
      );


    // updateLockPenalty
    assert.equal(
        (await this.chef.LOCK_PENALTY({ from: alice })).valueOf(),
        "0"
      );
      await expectRevert(
        this.chef.updateLockPeriod("10", { from: alice }),
        "Ownable: caller is not the owner"
      );
      await this.chef.updateLockPenalty("1234", { from: minter });
      assert.equal(
        (await this.chef.LOCK_PENALTY()).valueOf(),
        "1234"
      );
      await this.chef.updateLockPenalty("4321", { from: minter });
      assert.equal(
        (await this.chef.LOCK_PENALTY()).valueOf(),
        "4321"
      );


    // Treasury
    assert.equal((await this.chef.treasury_addr()).valueOf(), '0x0000000000000000000000000000000000000000');
    await expectRevert(this.chef.setTreasury(bob, { from: bob }), "Ownable: caller is not the owner");
    await this.chef.setTreasury(treasury, { from: minter });
    assert.equal((await this.chef.treasury_addr()).valueOf(), treasury);




    // devaddr

    // setMigrator

    // setItemHelper
  });

  it("guild tests", async () => {
    this.lp4 = await MockBEP20.new("LPToken", "LP1", "1000000", {
      from: minter,
    });
    this.lp5 = await MockBEP20.new("LPToken", "LP2", "1000000", {
      from: minter,
    });
    this.lp6 = await MockBEP20.new("LPToken", "LP3", "1000000", {
      from: minter,
    });
    this.lp7 = await MockBEP20.new("LPToken", "LP1", "1000000", {
      from: minter,
    });
    this.lp8 = await MockBEP20.new("LPToken", "LP2", "1000000", {
      from: minter,
    });
    this.lp9 = await MockBEP20.new("LPToken", "LP3", "1000000", {
      from: minter,
    });
    await this.chef.add("1000", this.lp1.address, true, true, { from: minter });
    await this.chef.add("1000", this.lp2.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("500", this.lp3.address, true, true, { from: minter });
    await this.chef.add("100", this.lp3.address, true, true, { from: minter });
    await this.chef.add("100", this.lp3.address, true, true, { from: minter });
    assert.equal((await this.chef.poolLength()).toString(), "9");

    await this.chef.set(0, "2000", true, { from: minter });

    // await time.advanceBlockTo('870');

    await expectRevert(
      this.chef.joinGuild(bob, { from: alice }),
      "guild not exit"
    );
    // Create guild
    await this.chef.joinGuild(bob, { from: bob });
    await this.chef.joinGuild(bob, { from: carol });

    await this.chef.joinGuild(bob, { from: alice });
    await expectRevert(
      this.chef.joinGuild(carol, { from: alice }),
      "Already in another guild"
    );

    await expectRevert(this.chef.leaveGuild({ from: eva }), "not in guild");

    // Allow gm dismiss and recreate without affect member
    await this.chef.leaveGuild({ from: bob });
    await this.chef.joinGuild(bob, { from: bob });

    await this.chef.leaveGuild({ from: alice });
    await this.chef.joinGuild(bob, { from: alice });
    await this.chef.leaveGuild({ from: bob });
    await this.chef.leaveGuild({ from: alice });
    await this.chef.joinGuild(bob, { from: bob });
    await this.chef.joinGuild(bob, { from: alice });

    await this.lp1.approve(this.chef.address, "1000", { from: alice });
    assert.equal((await this.ppx.balanceOf(alice)).toString(), "0");

    // TODO: Check bonus numbers after bonus level is determined.

    await this.chef.deposit(0, "20", { from: alice });
    //  await time.advanceBlockTo('873');
    // assert.equal((await this.chef.pendingCake(0, { from: alice })).toString(), '350877192982456140350');
    await this.chef.withdraw(0, "20", { from: alice });
    // 2000/5700 * 1000 * 2 = 701.75
    // assert.equal((await this.ppx.balanceOf(alice)).toString(), '701754385964912280701');
  });
});
