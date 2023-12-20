// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

/// @title IFeeCalculator
/// @author Neutral Labs Inc.
/// @notice This interface defines methods for calculating fees.
interface IFeeCalculator {
    /// @notice Calculates the deposit fee for a given amount.
    /// @param tco2 The address of the TCO2 token.
    /// @param pool The address of the pool.
    /// @param depositAmount The amount to be deposited.
    /// @return feeAmount The fee to be charged in pool
    /// tokens for this deposit.
    function calculateDepositFees(address tco2, address pool, uint256 depositAmount)
        external
        returns (uint256 feeAmount);

    /// @notice Calculates the redemption fees for a given amount.
    /// @param tco2 The address of the TCO2 token.
    /// @param pool The address of the pool.
    /// @param redemptionAmount The amount to be redeemed.
    /// @return feeAmount The fee to be charged in pool
    /// tokens for this redemption.
    function calculateRedemptionFees(address tco2, address pool, uint256 redemptionAmount)
        external
        returns (uint256 feeAmount);

    /// @notice Calculates the total fee among the recipients according to their shares.
    /// @param totalFee The total fee to be distributed.
    /// @return recipients The addresses of the fee recipients.
    /// @return feesDenominatedInPoolTokens The amount of fees each recipient should receive.
    function calculateFeeAmongShares(uint256 totalFee)
        external
        view
        returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens);
}
