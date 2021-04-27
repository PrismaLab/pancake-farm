const {ethers} = require("ethers");
const YAYAToken = artifacts.require('YAYAToken');
const PAPAToken = artifacts.require('PAPAToken');
const ItemNFT = artifacts.require('ItemNFT');
const FishingMaster = artifacts.require('FishingMaster');
const ItemHelper = artifacts.require('ItemHelper');
const MockBEP20 = artifacts.require("testlibs/MockBEP20");
const Multicall = artifacts.require("utils/Multicall");

module.exports = function(deployer) {

    deployer.then(async () => {
        let devaddr = '0x71E30416eF2D40daC33b649596a0e18E46225576';
        let initNum = ethers.utils.parseEther("1000");
        let yayaNum = ethers.utils.parseEther("100000000000");

        let yaya = await deployer.deploy(YAYAToken);
        await yaya.mint(devaddr,yayaNum);

        let papa = await deployer.deploy(PAPAToken, '100000000000000000000000000');
        await papa.mint(devaddr,initNum);

        let nft = await deployer.deploy(ItemNFT);
        let nftHelper = await deployer.deploy(ItemHelper);
        let master = await deployer.deploy(FishingMaster, yaya.address, papa.address, nft.address, nftHelper.address, devaddr, '40', '40','9');

        let lp1 = await MockBEP20.new("LPToken1", "LP1", initNum);
        let lp2 = await MockBEP20.new("LPToken2", "LP2", initNum);

        let multicall = await deployer.deploy(Multicall);

        await master.add("1000", lp1.address, true, true);
        await master.add("2000", lp2.address, true, true);

        await yaya.transferOwnership(master.address);
        await papa.transferOwnership(master.address);
        await nft.transferOwnership(master.address);

        await master.mintRandomNFT(devaddr);
        await master.mintRandomNFT(devaddr);
        await master.mintRandomNFT(devaddr);
        await master.mintRandomNFT(devaddr);
        await master.mintRandomNFT(devaddr);
        await master.updateMaxLevel(100);

        console.log("yaya",yaya.address);
        console.log("papa",papa.address);
        console.log("nft",nft.address);
        console.log("nftHelper",nftHelper.address);
        console.log("master",master.address);
        console.log("lp1",lp1.address);
        console.log("lp2",lp2.address);
        console.log("multicall",multicall.address);
    });
    
};
