const { assert } = require("chai");
const { advanceBlockTo } = require("@openzeppelin/test-helpers/src/time");
const { expectRevert, time } = require("@openzeppelin/test-helpers");
const ItemHelper = artifacts.require("ItemHelper");

contract("ItemHelper", ([alice, bob, carol, dev, minter]) => {
  beforeEach(async () => {
    this.itemHelper = await ItemHelper.new({ from: minter });
  });

  it("rand", async () => {
    // Non-view function does not return result to direct external calls.
    // So we just test exceptions here.
    await this.itemHelper.randMod(5, alice, { from: minter });

    await expectRevert(
      this.itemHelper.randMod(0, alice, { from: bob }),
      "rand: mod 0"
    );

    await expectRevert(
      this.itemHelper.randRange(10, 0, alice, { from: bob }),
      "rand: lower bound must less or equal to upper bound"
    );
    await this.itemHelper.randRange(3, 4, alice, { from: minter });
  });

  it("item", async () => {
    // Non-view function does not return result to direct external calls.
    // So we just test exceptions here.
    await this.itemHelper.genAttr(0, alice, { from: minter });
    await this.itemHelper.genAttr(10, alice, { from: minter });
    await this.itemHelper.reRollAttr(0, "1", alice, { from: minter });
    await this.itemHelper.reRollAttr(10, "1", alice, { from: minter });

    assert.equal(
      (await this.itemHelper.getMFBonus("0x100000004", 0, 0)).toString(),
      "1"
    );
    assert.equal(
      (await this.itemHelper.getMFBonus("0x100000003", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getMFBonus("0x100000002", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getMFBonus("0x100000001", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getMFBonus("0x100000000", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getMFBonus("0x100000005", 0, 0)).toString(),
      "0"
    );

    assert.equal(
      (await this.itemHelper.getMainTokenBonus("0x100000004", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getMainTokenBonus("0x100000003", 0, 0)).toString(),
      "1"
    );
    assert.equal(
      (await this.itemHelper.getMainTokenBonus("0x100000002", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getMainTokenBonus("0x100000001", 0, 0)).toString(),
      "1"
    );
    assert.equal(
      (await this.itemHelper.getMainTokenBonus("0x100000000", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getMainTokenBonus("0x100000005", 0, 0)).toString(),
      "0"
    );

    assert.equal(
      (await this.itemHelper.getExpTokenBonus("0x100000004", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getExpTokenBonus("0x100000003", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getExpTokenBonus("0x100000002", 0, 0)).toString(),
      "1"
    );
    assert.equal(
      (await this.itemHelper.getExpTokenBonus("0x100000001", 0, 0)).toString(),
      "1"
    );
    assert.equal(
      (await this.itemHelper.getExpTokenBonus("0x100000000", 0, 0)).toString(),
      "0"
    );
    assert.equal(
      (await this.itemHelper.getExpTokenBonus("0x100000005", 0, 0)).toString(),
      "0"
    );
  });
});
