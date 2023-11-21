// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

/// @title FeeCalculatorScript
/// @author Neutral Labs Inc.
/// @notice This contract is a script for fee calculation.
/// @dev It extends the Script contract from the forge-std library.
contract FeeCalculatorScript is Script {
    /// @notice Sets up the contract.
    function setUp() public {}

    /// @notice Runs the script, broadcasting the result.
    function run() public {
        vm.broadcast();
    }
}
