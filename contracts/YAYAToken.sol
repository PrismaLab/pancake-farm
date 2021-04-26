// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./libs/BEP20.sol";

// PapayaSwap YAYA Token WITHOUT Governance.
contract YAYAToken is BEP20("PapayaSwap YAYA Token", "YAYA") {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (FishingMaster).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /// @notice Burn `_amount` token from `_from`. Must only be called by the owner (FishingMaster).
    function burn(address _from, uint256 _amount) public onlyOwner {
        _burn(_from, _amount);
    }
}
