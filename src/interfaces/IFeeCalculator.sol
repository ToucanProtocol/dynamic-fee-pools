// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

struct FeeDistribution {
    address[] recipients;
    uint256[] shares;
}

/// @title IFeeCalculator
/// @author Neutral Labs Inc.
/// @notice This interface defines methods for calculating fees.
interface IFeeCalculator {
    /// @notice Calculates the deposit fee for a given amount.
    /// @param pool The address of the pool.
    /// @param tco2 The address of the TCO2 token.
    /// @param depositAmount The amount to be deposited.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateDepositFees(address pool, address tco2, uint256 depositAmount)
        external
        view
        returns (FeeDistribution memory feeDistribution);

    /// @notice Calculates the redemption fees for a given amount.
    /// @param pool The address of the pool.
    /// @param tco2s The addresses of the TCO2 token.
    /// @param redemptionAmounts The amounts to be redeemed.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateRedemptionFees(address pool, address[] calldata tco2s, uint256[] calldata redemptionAmounts)
        external
        view
        returns (FeeDistribution memory feeDistribution);

    /// @notice Estimates the TCO2 token redemption amount for a given pool token redemption amount.
    /// @dev Client that want to use a fixed pool token amount should use this function first to go from POOL to an approximation of the TCO2 they will get back, then use TCO2 to calculate the actual redemption fees they need to pay with calculateRedemptionFees.
    /// @param pool The address of the pool.
    /// @param tco2 The address of the TCO2 token.
    /// @param poolAmount the pool token amount to be redeemed.
    /// @return estimatedTCO2Amount estimated TCO2 token redemption amount for a give pool token redemption amount.
    function estimateTCO2RedemptionAmount(address pool, address tco2, uint256 poolAmount)
        external
        view
        returns (uint256 estimatedTCO2Amount);
}
