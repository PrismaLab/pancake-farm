const YAYAToken = artifacts.require('YAYAToken');
const PAPAToken = artifacts.require('PAPAToken');
const ItemNFT = artifacts.require('ItemNFT');
const FishingMaster = artifacts.require('FishingMaster');
const ItemHelper = artifacts.require('ItemHelper');

module.exports = function(deployer) {

    deployer.then(async () => {
        let devaddr = '0xA3e82C289f0887E5Ad7a65E4B794AB726e9CbFe8';
        let initNum = ethers.utils.formatEther("1000");
        let yayaNum = ethers.utils.formatEther("1000000000000");

        let yaya = await deployer.deploy(YAYAToken);
        await yaya.mint(devaddr,yayaNum);

        let papa = await deployer.deploy(PAPAToken, (10**18).toString);
        await papa.mint(devaddr,initNum);

        let nft = await deployer.deploy(ItemNFT);
        let nftHelper = await deployer.deploy(ItemHelper);
        let master = await deployer.deploy(FishingMaster, yaya.address, papa.address, nft.address, nftHelper.address, devaddr, '40', '40','10');

        let lp1 = await MockBEP20.new("LPToken1", "LP1", initNum);
        let lp2 = await MockBEP20.new("LPToken2", "LP2", initNum);

        await yaya.transferOwnership(master);
        await papa.transferOwnership(master);
        await nft.transferOwnership(master);

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
    });
    
};
