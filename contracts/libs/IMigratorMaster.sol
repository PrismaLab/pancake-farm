// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.4.0;

import "./IBEP20.sol";

interface IMigratorMaster {
    // Perform LP token migration from legacy system to new one.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to legacy LP tokens.
    // New system must mint EXACTLY the same amount of LP tokens or
    // else something bad will haitemTokenn. Traditional Swap does not
    // do that so be careful!
    function migrate(IBEP20 token) external returns (IBEP20);
}
