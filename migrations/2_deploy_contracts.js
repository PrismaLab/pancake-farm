const YAYAToken = artifacts.require('YAYAToken');
const PAPAToken = artifacts.require('PAPAToken');
const ItemNFT = artifacts.require('ItemNFT');
const FishingMaster = artifacts.require('FishingMaster');
const ItemHelper = artifacts.require('ItemHelper');

module.exports = function(deployer) {

    deployer.then(async () => {
        await deployer.deploy(YAYAToken);
        await deployer.deploy(PAPAToken);
        await deployer.deploy(ItemNFT);
        await deployer.deploy(ItemHelper);
        await deployer.deploy(FishingMaster, YAYAToken.address, PAPAToken.address, ItemNFT.address, ItemHelper.address, '0x790c01b3d9276aa8100c6842065f890f6abecb12', '1000', '1000','100');
    });
    
};
