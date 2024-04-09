// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import "./AbstractFeeCalculator.t.sol";

contract FeeCalculatorERC1155Test is AbstractFeeCalculatorTest {
    function setProjectSupply(address token, uint256 supply) internal override {
        mockPool.setERC1155Supply(address(token), 1, supply);
    }

    function calculateDepositFees(
        address pool,
        address token,
        uint256 amount
    ) internal view override returns (FeeDistribution memory) {
        return
            feeCalculator.calculateDepositFees(
                address(pool),
                address(token),
                1,
                amount
            );
    }

    function calculateRedemptionFees(
        address pool,
        address[] memory tokens,
        uint256[] memory amounts
    ) internal view override returns (FeeDistribution memory) {
        uint256[] memory tokenIds = new uint256[](tokens.length);
        tokenIds[0] = 1;
        return
            feeCalculator.calculateRedemptionFees(
                address(pool),
                tokens,
                tokenIds,
                amounts
            );
    }
}
