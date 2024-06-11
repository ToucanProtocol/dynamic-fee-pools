// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <security@toucan.earth> or visit security.toucan.earth
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {IFeeCalculator, FeeDistribution} from "./interfaces/IFeeCalculator.sol";
import "./interfaces/IPool.sol";

/// @title FlatFeeCalculator
/// @author Neutral Labs Inc. & Toucan Protocol
/// @notice This contract calculates deposit and redemption fees for a given pool.
/// @dev It implements the IFeeCalculator interface.
contract FlatFeeCalculator is IFeeCalculator, Ownable {
    /// @dev Version-related parameters. VERSION keeps track of production
    /// releases. VERSION_RELEASE_CANDIDATE keeps track of iterations
    /// of a VERSION in our staging environment.
    string public constant VERSION = "1.0.0";
    uint256 public constant VERSION_RELEASE_CANDIDATE = 2;

    uint256 public feeBasisPoints = 300;

    address[] private _recipients;
    uint256[] private _shares;

    event FeeBasisPointsUpdated(uint256 feeBasisPoints);
    event FeeSetup(address[] recipients, uint256[] shares);

    constructor() Ownable() {}

    /// @notice Sets the fee basis points.
    /// @dev Can only be called by the current owner.
    /// @param _feeBasisPoints The new fee basis points.
    function setFeeBasisPoints(uint256 _feeBasisPoints) external onlyOwner {
        require(_feeBasisPoints < 10000, "Fee basis points should be less than 10000");

        feeBasisPoints = _feeBasisPoints;
        emit FeeBasisPointsUpdated(_feeBasisPoints);
    }

    /// @notice Sets up the fee distribution among recipients.
    /// @dev Can only be called by the current owner.
    /// @param recipients The addresses of the fee recipients.
    /// @param shares The share of the fee each recipient should receive.
    function feeSetup(address[] memory recipients, uint256[] memory shares) external onlyOwner {
        require(recipients.length == shares.length, "Recipients and shares arrays must have the same length");

        uint256 totalShares = sumOf(shares);
        require(totalShares == 100, "Total shares must equal 100");

        _recipients = recipients;
        _shares = shares;
        emit FeeSetup(recipients, shares);
    }

    /// @notice Calculates the deposit fee for a given amount.
    /// @param depositAmount The amount to be deposited.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateDepositFees(address, address, uint256 depositAmount)
        external
        view
        override
        returns (FeeDistribution memory feeDistribution)
    {
        feeDistribution = _calculateFee(depositAmount);
    }

    /// @notice Calculates the fee shares and recipients based on the total fee.
    /// @param totalFee The total fee to be distributed.
    /// @return feeDistribution The recipients and the amount of fees each
    /// recipient should receive.
    function calculateFeeShares(uint256 totalFee) internal view returns (FeeDistribution memory feeDistribution) {
        uint256 recipientsLength = _recipients.length;
        uint256[] memory shares = new uint256[](recipientsLength);

        uint256 restFee = totalFee;
        for (uint256 i = 0; i < recipientsLength; i++) {
            shares[i] = (totalFee * _shares[i]) / 100;
            restFee -= shares[i];
        }

        // If any fee is left, it is distributed to the first recipient.
        // This may happen if any of the shares of the fee to be distributed
        // has leftover from the division by 100 above.
        shares[0] += restFee;

        feeDistribution.recipients = _recipients;
        feeDistribution.shares = shares;
    }

    /// @notice Calculates the redemption fees for a given amount.
    /// @param tco2s The addresses of the TCO2 token.
    /// @param redemptionAmounts The amounts to be redeemed.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateRedemptionFees(address, address[] calldata tco2s, uint256[] calldata redemptionAmounts)
        external
        view
        override
        returns (FeeDistribution memory feeDistribution)
    {
        require(tco2s.length == redemptionAmounts.length, "length mismatch");

        uint256 totalRedemptionAmount = sumOf(redemptionAmounts);

        feeDistribution = _calculateFee(totalRedemptionAmount);
    }

    /// @notice Calculates the deposit fee for a given amount of an ERC1155 project.
    /// @param depositAmount The amount to be deposited.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateDepositFees(address, address, uint256, uint256 depositAmount)
        external
        view
        override
        returns (FeeDistribution memory feeDistribution)
    {
        feeDistribution = _calculateFee(depositAmount);
    }

    /// @notice Calculates the redemption fees for a given amount on ERC1155 projects.
    /// @param erc1155s The addresses of the ERC1155 projects.
    /// @param tokenIds The tokenIds of the project vintages.
    /// @param redemptionAmounts The amounts to be redeemed.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateRedemptionFees(
        address,
        address[] calldata erc1155s,
        uint256[] calldata tokenIds,
        uint256[] calldata redemptionAmounts
    ) external view override returns (FeeDistribution memory feeDistribution) {
        require(erc1155s.length == tokenIds.length, "erc1155s/tokenIds length mismatch");
        require(erc1155s.length == redemptionAmounts.length, "erc1155s/redemptionAmounts length mismatch");

        uint256 totalRedemptionAmount = sumOf(redemptionAmounts);

        feeDistribution = _calculateFee(totalRedemptionAmount);
    }

    /// @notice Returns the current fee setup.
    /// @return recipients shares The fee recipients and their share of the total fee.
    function getFeeSetup() external view returns (address[] memory recipients, uint256[] memory shares) {
        recipients = _recipients;
        shares = _shares;
    }

    /// @notice Calculates the fee for a given amount.
    /// @param requestedAmount The amount to be used for the fee calculation.
    /// @return feeDistribution How the fee is meant to be
    function _calculateFee(uint256 requestedAmount) internal view returns (FeeDistribution memory) {
        require(requestedAmount != 0, "requested amount must be > 0");

        uint256 feeAmount = requestedAmount * feeBasisPoints / 10000;

        require(feeAmount <= requestedAmount, "Fee must be lower or equal to requested amount");
        require(feeAmount != 0, "Fee must be greater than 0");

        return calculateFeeShares(feeAmount);
    }

    function sumOf(uint256[] memory array) private pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < array.length; i++) {
            total += array[i];
        }
        return total;
    }
}
