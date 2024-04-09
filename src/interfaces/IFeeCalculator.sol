// SPDX-FileCopyrightText: 2024 Toucan Protocol
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

    /// @notice Calculates the deposit fee for a given amount of an ERC1155 project.
    /// @param pool The address of the pool.
    /// @param erc1155 The address of the ERC1155 project
    /// @param tokenId The tokenId of the vintage.
    /// @param depositAmount The amount to be deposited.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateDepositFees(address pool, address erc1155, uint256 tokenId, uint256 depositAmount) 
        external
        view
        returns (FeeDistribution memory feeDistribution);

    /// @notice Calculates the redemption fees for a given amount on ERC1155 projects.
    /// @param pool The address of the pool.
    /// @param erc1155s The addresses of the ERC1155 projects.
    /// @param tokenIds The tokenIds of the project vintages.
    /// @param redemptionAmounts The amounts to be redeemed.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateRedemptionFees(address pool, address[] calldata erc1155s, uint256[] calldata tokenIds, uint256[] calldata redemptionAmounts) 
        external
        view
        returns (FeeDistribution memory feeDistribution);
}
