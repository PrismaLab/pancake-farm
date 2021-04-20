// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libs/IBEP20.sol";
import "../libs/BEP20.sol";
import "../libs/IMigratorMaster.sol";
import "../libs/SafeBEP20.sol";


contract MockIMigrator is IMigratorMaster, BEP20 {
    using SafeBEP20 for IBEP20;

    IBEP20 public oldToken;

    constructor(
        string memory name,
        string memory symbol,
        uint256 supply,
        IBEP20 _oldToken
    ) BEP20(name, symbol) {
        oldToken = _oldToken;
        _mint(msg.sender, supply);

    }

    

    function migrate(IBEP20 token) external override returns (IBEP20) {
        require(address(token) == address(oldToken), "migrate: must correct token");
        uint256 bal = token.balanceOf(msg.sender);
        if (bal > 0) {
            oldToken.safeTransferFrom(msg.sender, address(this), bal);
            _mint(msg.sender, bal);
        }
        return this; 
    }
}