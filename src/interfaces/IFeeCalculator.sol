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
        view
        returns (uint256 feeAmount);

    /// @notice Calculates the redemption fees for a given amount.
    /// @param tco2 The address of the TCO2 token.
    /// @param pool The address of the pool.
    /// @param redemptionAmount The amount to be redeemed.
    /// @return feeAmount The fee to be charged in pool
    /// tokens for this redemption.
    function calculateRedemptionFees(address tco2, address pool, uint256 redemptionAmount)
        external
        view
        returns (uint256 feeAmount);

    /// @notice Calculates the fee shares and recipients for a deposit based on the total fee.
    /// @param totalFee The total fee to be shared.
    /// @return recipients The addresses of the fee recipients.
    /// @return feesDenominatedInPoolTokens The amount of fees each recipient should receive.
    function calculateDepositFeeShares(uint256 totalFee)
        external
        view
        returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens);

    /// @notice Calculates the fee shares and recipients for a redemption based on the total fee.
    /// @param totalFee The total fee to be shared.
    /// @return recipients The addresses of the fee recipients.
    /// @return feesDenominatedInPoolTokens The amount of fees each recipient should receive.
    function calculateRedemptionFeeShares(uint256 totalFee)
        external
        view
        returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens);
}
