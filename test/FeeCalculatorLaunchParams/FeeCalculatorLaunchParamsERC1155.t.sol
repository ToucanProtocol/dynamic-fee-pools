// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import "./AbstractFeeCalculatorLaunchParams.t.sol";

contract FeeCalculatorLaunchParamsERC1155Test is AbstractFeeCalculatorLaunchParamsTest {
    function setProjectSupply(address token, uint256 supply) internal override {
        mockPool.setERC1155Supply(address(token), 1, supply);
    }

    function calculateDepositFees(address pool, address token, uint256 amount)
        internal
        view
        override
        returns (FeeDistribution memory)
    {
        return feeCalculator.calculateDepositFees(address(pool), address(token), 1, amount);
    }
}
