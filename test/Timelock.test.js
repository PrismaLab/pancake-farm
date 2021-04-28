const { expectRevert, time } = require("@openzeppelin/test-helpers");
const ethers = require("ethers");
const YAYAToken = artifacts.require("YAYAToken");
const FishingMaster = artifacts.require("FishingMaster");
const MockBEP20 = artifacts.require("testlibs/MockBEP20");
const Timelock = artifacts.require("Timelock");
const PAPAToken = artifacts.require("PAPAToken");
const ItemNFT = artifacts.require("ItemNFT");
const ItemHelper = artifacts.require("ItemHelper");

function encodeParameters(types, values) {
  const abi = new ethers.utils.AbiCoder();
  return abi.encode(types, values);
}

contract("Timelock", ([alice, bob, carol, dev, community, reserve, minter]) => {
  beforeEach(async () => {
    this.ppy = await PAPAToken.new("1000000000000000000000000000", {
      from: alice,
    });
    this.timelock = await Timelock.new(bob, "28800", { from: alice }); //8hours
  });

  it("should not allow non-owner to do operation", async () => {
    await this.ppy.transferOwnership(this.timelock.address, { from: alice });
    await expectRevert(
      this.ppy.transferOwnership(carol, { from: alice }),
      "Ownable: caller is not the owner"
    );
    await expectRevert(
      this.ppy.transferOwnership(carol, { from: bob }),
      "Ownable: caller is not the owner"
    );
    await expectRevert(
      this.timelock.queueTransaction(
        this.ppy.address,
        "0",
        "transferOwnership(address)",
        encodeParameters(["address"], [carol]),
        (await time.latest()).add(time.duration.hours(6)),
        { from: alice }
      ),
      "Timelock::queueTransaction: Call must come from admin."
    );
  });

  it("should do the timelock thing", async () => {
    await this.ppy.transferOwnership(this.timelock.address, { from: alice });
    const eta = (await time.latest()).add(time.duration.hours(9));
    await this.timelock.queueTransaction(
      this.ppy.address,
      "0",
      "transferOwnership(address)",
      encodeParameters(["address"], [carol]),
      eta,
      { from: bob }
    );
    await time.increase(time.duration.hours(1));
    await expectRevert(
      this.timelock.executeTransaction(
        this.ppy.address,
        "0",
        "transferOwnership(address)",
        encodeParameters(["address"], [carol]),
        eta,
        { from: bob }
      ),
      "Timelock::executeTransaction: Transaction hasn't surpassed time lock."
    );
    await time.increase(time.duration.hours(8));
    await this.timelock.executeTransaction(
      this.ppy.address,
      "0",
      "transferOwnership(address)",
      encodeParameters(["address"], [carol]),
      eta,
      { from: bob }
    );
    assert.equal((await this.ppy.owner()).valueOf(), carol);
  });

  it("should also work with FishingMaster", async () => {
    this.lp1 = await MockBEP20.new("LPToken", "LP", "10000000000", {
      from: minter,
    });
    this.lp2 = await MockBEP20.new("LPToken", "LP", "10000000000", {
      from: minter,
    });
    this.ppx = await YAYAToken.new({ from: minter });
    this.ppe = await ItemNFT.new({ from: minter });
    this.itemHelper = await ItemHelper.new({ from: minter });
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
      "0",
      { from: alice }
    );
    await this.ppy.transferOwnership(this.chef.address, { from: alice });
    await this.ppx.transferOwnership(this.chef.address, { from: minter });
    await this.ppe.transferOwnership(this.chef.address, { from: minter });
    await this.chef.add("100", this.lp1.address, true, { from: alice });
    await this.chef.transferOwnership(this.timelock.address, { from: alice });
    await expectRevert(
      this.chef.add("100", this.lp1.address, true, { from: alice }),
      "revert Ownable: caller is not the owner"
    );

    const eta = (await time.latest()).add(time.duration.hours(9));
    await this.timelock.queueTransaction(
      this.chef.address,
      "0",
      "transferOwnership(address)",
      encodeParameters(["address"], [minter]),
      eta,
      { from: bob }
    );
    // await this.timelock.queueTransaction(
    //     this.chef.address, '0', 'add(uint256,address,bool)',
    //     encodeParameters(['uint256', 'address', 'bool'], ['100', this.lp2.address, false]), eta, { from: bob },
    // );
    await time.increase(time.duration.hours(9));
    await this.timelock.executeTransaction(
      this.chef.address,
      "0",
      "transferOwnership(address)",
      encodeParameters(["address"], [minter]),
      eta,
      { from: bob }
    );
    await expectRevert(
      this.chef.add("100", this.lp1.address, false, true, { from: alice }),
      "revert Ownable: caller is not the owner"
    );
    await this.chef.add("100", this.lp1.address, true, true, { from: minter });
    // await this.timelock.executeTransaction(
    //     this.chef.address, '0', 'add(uint256,address,bool)',
    //     encodeParameters(['uint256', 'address', 'bool'], ['100', this.lp2.address, false]), eta, { from: bob },
    // );
    // assert.equal((await this.chef.poolInfo('0')).valueOf().allocPoint, '200');
    // assert.equal((await this.chef.totalAllocPoint()).valueOf(), '300');
    // assert.equal((await this.chef.poolLength()).valueOf(), '2');
  });
});
