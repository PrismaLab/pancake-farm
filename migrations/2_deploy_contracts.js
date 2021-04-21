const YAYAToken = artifacts.require('YAYAToken');
const PAPAToken = artifacts.require('PAPAToken');
const ItemNFT = artifacts.require('ItemNFT');
const FishingMaster = artifacts.require('FishingMaster');
const ItemHelper = artifacts.require('ItemHelper');

module.exports = function(deployer) {

    deployer.then(async () => {
        await deployer.deploy(YAYAToken);
        await deployer.deploy(PAPAToken, '100000000000000000000000000');
        await deployer.deploy(ItemNFT);
        await deployer.deploy(ItemHelper);
        await deployer.deploy(FishingMaster, YAYAToken.address, PAPAToken.address, ItemNFT.address, ItemHelper.address, '0x7AF418089720dF17dE2C3b296B223b7D4A3Da617', '1000000000000000000000', '100000000000000000000','10');
    });
    
};
