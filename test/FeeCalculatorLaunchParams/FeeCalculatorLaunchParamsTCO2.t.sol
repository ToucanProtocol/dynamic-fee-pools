// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import "./AbstractFeeCalculatorLaunchParams.t.sol";

contract FeeCalculatorLaunchParamsTCO2Test is AbstractFeeCalculatorLaunchParamsTest {
    function setProjectSupply(address token, uint256 supply) internal override {
        mockPool.setTCO2Supply(address(token), supply);
    }

    function calculateDepositFees(address pool, address token, uint256 amount)
        internal
        view
        override
        returns (FeeDistribution memory)
    {
        return feeCalculator.calculateDepositFees(address(pool), address(token), amount);
    }
}
