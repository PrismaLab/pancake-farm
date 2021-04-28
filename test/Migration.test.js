const { assert } = require("chai");
const { advanceBlockTo } = require("@openzeppelin/test-helpers/src/time");
const { expectRevert, time } = require("@openzeppelin/test-helpers");
const YAYAToken = artifacts.require("YAYAToken");
const PAPAToken = artifacts.require("PAPAToken");
const ItemNFT = artifacts.require("ItemNFT");
const FishingMaster = artifacts.require("FishingMaster");
const ItemHelper = artifacts.require("ItemHelper");
const MockBEP20 = artifacts.require("testlibs/MockBEP20");

const MockItemHelper = artifacts.require("testlibs/MockItemHelper");
const MockIMigrator = artifacts.require("testlibs/MockIMigrator");

contract("Migration", ([alice, bob, carol, dev,reserve,community, minter]) => {
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

    this.chef = await FishingMaster.new(
      this.ppx.address,
      this.ppy.address,
      this.ppe.address,
      this.itemHelper.address,
      dev,
      reserve,
      community,
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

    this.itemHelper2 = await MockItemHelper.new({ from: minter });
    this.lp4 = await MockIMigrator.new(
      "LPToken",
      "LP4",
      "1000000",
      this.lp1.address,
      { from: minter }
    );
  });

  it("ItemHelper migration", async () => {
    await expectRevert(
      this.chef.setItemHelper(this.itemHelper2.address, { from: alice }),
      "Ownable: caller is not the owner"
    );

    this.chef.setItemHelper(this.itemHelper2.address, { from: minter });
    // should work!
    await this.chef.mintRandomNFT(alice, { from: minter }); // 1
  });

  it("LP Migration", async () => {
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

    await expectRevert(
      this.chef.setMigrator(this.lp4.address, { from: alice }),
      "Ownable: caller is not the owner"
    );
    assert.equal(
      (await this.lp1.balanceOf(this.chef.address)).toString(),
      "20"
    );
    assert.equal((await this.lp4.balanceOf(this.chef.address)).toString(), "0");
    await this.chef.setMigrator(this.lp4.address, { from: minter });
    await this.chef.migrate(0);
    assert.equal((await this.lp1.balanceOf(this.chef.address)).toString(), "0");
    assert.equal(
      (await this.lp4.balanceOf(this.chef.address)).toString(),
      "20"
    );

    await this.chef.withdraw(0, "20", { from: alice });

    assert.equal((await this.lp1.balanceOf(this.chef.address)).toString(), "0");
    assert.equal((await this.lp4.balanceOf(this.chef.address)).toString(), "0");

    assert.equal((await this.lp1.balanceOf(alice)).toString(), "1980");
    assert.equal((await this.lp4.balanceOf(alice)).toString(), "20");
  });
});
