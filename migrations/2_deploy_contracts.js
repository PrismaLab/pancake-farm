const { ethers } = require("ethers");
const YAYAToken = artifacts.require("YAYAToken");
const PAPAToken = artifacts.require("PAPAToken");
const ItemNFT = artifacts.require("ItemNFT");
const FishingMaster = artifacts.require("FishingMaster");
const ItemHelper = artifacts.require("ItemHelper");
const MockBEP20 = artifacts.require("testlibs/MockBEP20");
const Multicall = artifacts.require("utils/Multicall");

module.exports = function (deployer, network) {
  deployer.then(async () => {
    var accounts;
    await web3.eth.getAccounts(function(err,res) { accounts = res; });
    var owner = accounts[0]; // first account

    let devaddr = owner; // change it!
    let reserve_addr = owner; // change it!
    let community_addr = owner; // change it!

    let yayaPerblock = "100";
    let papaPerblock = "100";
    let startBlock = "1";
    let papaCap = "100000000000000000000000000";

    let yaya = await deployer.deploy(YAYAToken);
    let papa = await deployer.deploy(PAPAToken, papaCap);
    let nft = await deployer.deploy(ItemNFT);
    let nftHelper = await deployer.deploy(ItemHelper);

    let master = await deployer.deploy(
      FishingMaster,
      yaya.address,
      papa.address,
      nft.address,
      nftHelper.address,
      devaddr,
      reserve_addr,
      community_addr,
      yayaPerblock,
      papaPerblock,
      startBlock
    );

    if (network != "bsc" && network != "test") {
      await yaya.mint(devaddr, ethers.utils.parseEther("100000000000"));
      await papa.mint(devaddr, ethers.utils.parseEther("1000"));
    }

    let multicall = await deployer.deploy(Multicall);

    await yaya.transferOwnership(master.address);
    await papa.transferOwnership(master.address);
    await nft.transferOwnership(master.address);

    if (network != "bsc" && network != "test") {
      // For test environment
      await master.mintRandomNFT(devaddr);
      await master.mintRandomNFT(devaddr);
      await master.mintRandomNFT(devaddr);
      await master.mintRandomNFT(devaddr);
      await master.mintRandomNFT(devaddr);
      await master.updateMaxLevel(100);
      let lp1 = await MockBEP20.new("LPToken1", "LP1", ethers.utils.parseEther("1000"));
      let lp2 = await MockBEP20.new("LPToken2", "LP2", ethers.utils.parseEther("1000"));

      await master.add("1000", lp1.address, true, true);
      await master.add("2000", lp2.address, true, true);

      console.log("yaya", yaya.address);
      console.log("papa", papa.address);
      console.log("nft", nft.address);
      console.log("nftHelper", nftHelper.address);
      console.log("master", master.address);
      console.log("lp1", lp1.address);
      console.log("lp2", lp2.address);
      console.log("multicall", multicall.address);
    }
  });
};
