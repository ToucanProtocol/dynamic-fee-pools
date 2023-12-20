// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

/// @title IRedemptionFeeCalculator
/// @author Neutral Labs Inc.
/// @notice This interface defines a method for calculating redemption fees.
interface IRedemptionFeeCalculator {
    /// @notice Calculates the redemption fees for a given amount.
    /// @param tco2 The address of the TCO2 token.
    /// @param pool The address of the pool.
    /// @param depositAmount The amount to be redeemed.
    /// @return recipients The addresses of the fee recipients.
    /// @return feesDenominatedInPoolTokens The amount of fees each recipient should receive.
    function calculateRedemptionFees(address tco2, address pool, uint256 depositAmount)
        external
        returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens);

    /// @notice Calculates the redemption fees across multiple TCO2s for a given amount.
    /// @param tco2s The addresses of the TCO2 tokens.
    /// @param pool The address of the pool.
    /// @param amounts The amounts to be redeemed per TCO2.
    /// @return recipients The addresses of the fee recipients.
    /// @return feesDenominatedInPoolTokens The amount of fees each recipient should receive.
    function calculateRedemptionFeesMany(address[] calldata tco2s, address pool, uint256[] calldata amounts)
        external
        returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens);
}
