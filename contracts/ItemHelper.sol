// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Item helper functions for Papaya ItemNFT
contract ItemHelper {
    using SafeMath for uint256;

    // !!!SHOULD BE STATELESS EXCEPT FOR RANDOM NONCE!!!
    // Intializing the state variable
    uint256 randNonce = 42;
    // !!!SHOULD BE STATELESS EXCEPT FOR RANDOM NONCE!!!

    enum ItemAttrEffect {NONE, ALL_TOKEN_BUFF, EXP_TOKEN_BUFF, MAIN_TOKEN_BUFF, MF_BUFF}
    uint8 constant itemAttrEffectSize = 4;

    // Decode attr and check if it has exp token bonus to given pool.
    function getExpTokenBonus(
        uint256 attr,
        uint256, /*level*/
        uint256 /*pid*/
    ) public pure returns (uint256) {
        uint256 attr_type = attr % (2**32);

        if (
            attr_type == uint256(ItemAttrEffect.ALL_TOKEN_BUFF) || attr_type == uint256(ItemAttrEffect.EXP_TOKEN_BUFF)
        ) {
            return (attr >> 32);
        }
        return 0;
    }

    // Decode attr and check if it has main token bonus to given pool.
    function getMainTokenBonus(
        uint256 attr,
        uint256, /*level*/
        uint256 /*pid*/
    ) public pure returns (uint256) {
        uint256 attr_type = attr % (2**32);

        if (
            attr_type == uint256(ItemAttrEffect.ALL_TOKEN_BUFF) || attr_type == uint256(ItemAttrEffect.MAIN_TOKEN_BUFF)
        ) {
            return (attr >> 32);
        }

        return 0;
    }

    // Decode attr and check if it has mf bonus to given pool.
    function getMFBonus(
        uint256 attr,
        uint256, /*level*/
        uint256 /*pid*/
    ) public pure returns (uint256) {
        uint256 attr_type = attr % (2**32);

        if (attr_type == uint256(ItemAttrEffect.MF_BUFF)) {
            return (attr >> 32);
        }
        return 0;
    }

    function genRandomItem(uint256 userLevel, address _sender)
        public
        returns (
            uint256,
            uint256,
            uint256[6] memory
        )
    {
        // Pure random function version 0
        uint256 template = randMod(10, _sender);
        // We do not plan to change the level logic so we leave it here.
        uint256 minLevel = 0;
        if (userLevel > 10) {
            minLevel = userLevel.sub(10);
        }
        uint256 maxLevel = userLevel.add(10);

        uint256 level = randRange(minLevel, maxLevel, _sender);
        level = level - (level % 5) + 5;
        uint256[6] memory attr;
        // genAttr actually will ask itemHelper to generate attributes.
        for (uint256 i = 0; i < 6; i++) {
            attr[i] = genAttr(level, _sender);
            if (randMod(256, _sender) >= 2) {
                break;
            }
        }
        return (level, template, attr);
    }

    // Generate a single attr.
    function genAttr(uint256 level, address _sender) public returns (uint256) {
        if (level == 0) {
            level = 1;
        }
        uint256 r = rand(_sender);
        uint256 attr = ((r % (2**32)) % itemAttrEffectSize) + 1;
        r >>= 32;
        uint256 attr_v = ((r % (2**32)) % level) + 1;
        // divide 5 and round up if it is mf
        if (attr == uint256(ItemAttrEffect.MF_BUFF)) {
            attr_v = attr_v.add(4).div(5);
        }
        return (attr | (attr_v << 32));
    }

    // Generate a single attr.
    function reRollAttr(
        uint256 level,
        uint256 oldAttr,
        address _sender
    ) public returns (uint256) {
        if (level == 0) {
            level = 1;
        }
        uint256 r = rand(_sender);
        uint256 attr = oldAttr % (2**32);
        uint256 attr_v = ((r % (2**32)) % level) + 1;
        // divide 5 and round up if it is mf
        if (attr == uint256(ItemAttrEffect.MF_BUFF)) {
            attr_v = attr_v.add(4).div(5);
        }
        return (attr | (attr_v << 32));
    }

    function cacheBonus(uint256 level, uint256[6] memory itemAttr)
        public
        pure
        returns (
            uint256 expBonus,
            uint256 mainBonus,
            uint256 mfBonus
        )
    {
        // TODO: return uint256(-1) if it is pid related so that it cannot be cached.
        for (uint8 j = 0; j < 6; j++) {
            if (itemAttr[j] == 0) {
                break;
            }
            expBonus = expBonus.add(getExpTokenBonus(itemAttr[j], level, 0));
            mainBonus = mainBonus.add(getExpTokenBonus(itemAttr[j], level, 0));
            mfBonus = mfBonus.add(getExpTokenBonus(itemAttr[j], level, 0));
        }
    }

    // Defining a function
    //
    // We choose not to use an oracle for randomness in the NFT case for the following reasons:
    // The lagest danger of such PRNG is the case that a miner may reject certain result.
    // However, in the current design, a user can always have another roll several hours later.
    // Therefore he will loss gas fee for rejecting a block and gain almost nothing.
    function rand(address _sender) internal returns (uint256) {
        // increase nonce
        randNonce++;
        return uint256(keccak256(abi.encodePacked(block.timestamp, _sender, randNonce)));
    }

    // Defining a function to generate
    // a random number mod modulus
    function randMod(uint256 _modulus, address _sender) public returns (uint256) {
        require(_modulus > 0, "rand: mod 0");
        return rand(_sender) % _modulus;
    }

    // Defining a function to generate
    // a random number in [lower, upper]
    function randRange(
        uint256 lower,
        uint256 upper,
        address _sender
    ) public returns (uint256) {
        require(lower <= upper, "rand: lower bound must less or equal to upper bound");
        return randMod(upper - lower + 1, _sender) + lower;
    }
}
