// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {SD59x18, sd, intoUint256} from "@prb/math/src/SD59x18.sol";

import {IFeeCalculator, FeeDistribution} from "./interfaces/IFeeCalculator.sol";
import "./interfaces/IPool.sol";

/// @title FeeCalculator
/// @author Neutral Labs Inc.
/// @notice This contract calculates deposit and redemption fees for a given pool.
/// @dev It implements the IFeeCalculator interface.
contract FeeCalculator is IFeeCalculator, Ownable {
    SD59x18 private zero = sd(0);
    SD59x18 private one = sd(1e18);

    SD59x18 private depositFeeScale = sd(0.18 * 1e18);
    SD59x18 private depositFeeRatioScale = sd(0.99 * 1e18);
    SD59x18 private singleAssetDepositRelativeFee = sd(0.1 * 1e18);

    SD59x18 private redemptionFeeScale = sd(0.3 * 1e18);
    SD59x18 private redemptionFeeShift = sd(0.1 * 1e18); //-log10(0+0.1)=1 -> 10^-1

    function redemptionFeeConstant() private view returns (SD59x18) {
        return redemptionFeeScale * (one + redemptionFeeShift).log10(); //0.0413926851582251=log10(1+0.1)
    }

    SD59x18 private singleAssetRedemptionRelativeFee = sd(0.1 * 1e18);
    SD59x18 private dustAssetRedemptionRelativeFee = sd(0.3 * 1e18);

    address[] private _recipients;
    uint256[] private _shares;

    constructor() Ownable() {}

    /// @notice Sets the deposit fee scale.
    /// @dev Can only be called by the current owner.
    /// @param _depositFeeScale The new deposit fee scale.
    function setDepositFeeScale(int256 _depositFeeScale) external onlyOwner {
        SD59x18 depositFeeScaleSD = sd(_depositFeeScale);
        require(depositFeeScaleSD >= zero && depositFeeScaleSD <= one, "Deposit fee scale must be between 0 and 1");
        depositFeeScale = depositFeeScaleSD;
    }

    /// @notice Sets the deposit fee ratio scale.
    /// @dev Can only be called by the current owner.
    /// @param _depositFeeRatioScale The new deposit fee ratio scale.
    function setDepositFeeRatioScale(int256 _depositFeeRatioScale) external onlyOwner {
        SD59x18 depositFeeRatioScaleSD = sd(_depositFeeRatioScale);
        require(depositFeeRatioScaleSD >= zero, "Deposit fee ratio scale must be above 0");
        depositFeeRatioScale = depositFeeRatioScaleSD;
    }

    /// @notice Sets the single asset deposit relative fee.
    /// @dev Can only be called by the current owner.
    /// @param _singleAssetDepositRelativeFee The new single asset deposit relative fee.
    function setSingleAssetDepositRelativeFee(int256 _singleAssetDepositRelativeFee) external onlyOwner {
        SD59x18 singleAssetDepositRelativeFeeSD = sd(_singleAssetDepositRelativeFee);
        require(
            singleAssetDepositRelativeFeeSD >= zero && singleAssetDepositRelativeFeeSD <= one,
            "Single asset deposit relative fee must be between 0 and 1"
        );
        singleAssetDepositRelativeFee = singleAssetDepositRelativeFeeSD;
    }

    /// @notice Sets the redemption fee scale.
    /// @dev Can only be called by the current owner.
    /// @param _redemptionFeeScale The new redemption fee scale.
    function setRedemptionFeeScale(int256 _redemptionFeeScale) external onlyOwner {
        SD59x18 redemptionFeeScaleSD = sd(_redemptionFeeScale);
        require(
            redemptionFeeScaleSD >= zero && redemptionFeeScaleSD <= one, "Redemption fee scale must be between 0 and 1"
        );
        redemptionFeeScale = redemptionFeeScaleSD;
    }

    /// @notice Sets the redemption fee shift.
    /// @dev Can only be called by the current owner.
    /// @param _redemptionFeeShift The new redemption fee shift.
    function setRedemptionFeeShift(int256 _redemptionFeeShift) external onlyOwner {
        SD59x18 redemptionFeeShiftSD = sd(_redemptionFeeShift);
        require(
            redemptionFeeShiftSD >= zero && redemptionFeeShiftSD <= one, "Redemption fee shift must be between 0 and 1"
        );
        redemptionFeeShift = redemptionFeeShiftSD;
    }

    /// @notice Sets the single asset redemption relative fee.
    /// @dev Can only be called by the current owner.
    /// @param _singleAssetRedemptionRelativeFee The new single asset redemption relative fee.
    function setSingleAssetRedemptionRelativeFee(int256 _singleAssetRedemptionRelativeFee) external onlyOwner {
        SD59x18 singleAssetRedemptionRelativeFeeSD = sd(_singleAssetRedemptionRelativeFee);
        require(
            singleAssetRedemptionRelativeFeeSD >= zero && singleAssetRedemptionRelativeFeeSD <= one,
            "Single asset redemption relative fee must be between 0 and 1"
        );
        singleAssetRedemptionRelativeFee = singleAssetRedemptionRelativeFeeSD;
    }

    /// @notice Sets the dust asset redemption relative fee.
    /// @dev Can only be called by the current owner.
    /// @param _dustAssetRedemptionRelativeFee The new dust asset redemption relative fee.
    function setDustAssetRedemptionRelativeFee(int256 _dustAssetRedemptionRelativeFee) external onlyOwner {
        SD59x18 dustAssetRedemptionRelativeFeeSD = sd(_dustAssetRedemptionRelativeFee);
        require(
            dustAssetRedemptionRelativeFeeSD >= zero && dustAssetRedemptionRelativeFeeSD <= one,
            "Dust asset redemption relative fee must be between 0 and 1"
        );
        dustAssetRedemptionRelativeFee = dustAssetRedemptionRelativeFeeSD;
    }

    /// @notice Sets up the fee distribution among recipients.
    /// @dev Can only be called by the current owner.
    /// @param recipients The addresses of the fee recipients.
    /// @param shares The share of the fee each recipient should receive.
    function feeSetup(address[] memory recipients, uint256[] memory shares) external onlyOwner {
        require(recipients.length == shares.length, "Recipients and shares arrays must have the same length");

        uint256 totalShares = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }
        require(totalShares == 100, "Total shares must equal 100");

        _recipients = recipients;
        _shares = shares;
    }

    /// @notice Calculates the deposit fee for a given amount.
    /// @param pool The address of the pool.
    /// @param tco2 The address of the TCO2 token.
    /// @param depositAmount The amount to be deposited.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateDepositFees(address pool, address tco2, uint256 depositAmount)
        external
        view
        override
        returns (FeeDistribution memory feeDistribution)
    {
        require(depositAmount > 0, "depositAmount must be > 0");

        uint256 feeAmount = getDepositFee(depositAmount, getTokenBalance(pool, tco2), getTotalSupply(pool));

        require(feeAmount <= depositAmount, "Fee must be lower or equal to deposit amount");
        require(feeAmount > 0, "Fee must be greater than 0");
        feeDistribution = calculateFeeShares(feeAmount);
    }

    /// @notice Calculates the fee shares and recipients based on the total fee.
    /// @param totalFee The total fee to be distributed.
    /// @return feeDistribution The recipients and the amount of fees each
    /// recipient should receive.
    function calculateFeeShares(uint256 totalFee) internal view returns (FeeDistribution memory feeDistribution) {
        uint256[] memory shares = new uint256[](_recipients.length);

        uint256 restFee = totalFee;

        for (uint256 i = 0; i < _recipients.length; i++) {
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
    /// @param pool The address of the pool.
    /// @param tco2s The addresses of the TCO2 token.
    /// @param redemptionAmounts The amounts to be redeemed.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateRedemptionFees(address pool, address[] calldata tco2s, uint256[] calldata redemptionAmounts)
        external
        view
        override
        returns (FeeDistribution memory feeDistribution)
    {
        require(tco2s.length == redemptionAmounts.length, "length mismatch");
        require(tco2s.length == 1, "only one");
        address tco2 = tco2s[0];
        uint256 redemptionAmount = redemptionAmounts[0];

        require(redemptionAmount > 0, "redemptionAmount must be > 0");

        uint256 feeAmount = getRedemptionFee(redemptionAmount, getTokenBalance(pool, tco2), getTotalSupply(pool));

        require(feeAmount <= redemptionAmount, "Fee must be lower or equal to redemption amount");
        require(feeAmount > 0, "Fee must be greater than 0");
        feeDistribution = calculateFeeShares(feeAmount);
    }

    /// @notice Gets the balance of the TCO2 token in a given pool.
    /// @param pool The address of the pool.
    /// @param tco2 The address of the TCO2 token.
    /// @return The balance of the TCO2 token in the pool.
    function getTokenBalance(address pool, address tco2) private view returns (uint256) {
        uint256 tokenBalance = IERC20(tco2).balanceOf(pool);
        return tokenBalance;
    }

    /// @notice Gets the total supply of a given pool.
    /// @param pool The address of the pool.
    /// @return The total supply of the pool.
    function getTotalSupply(address pool) private view returns (uint256) {
        uint256 totalSupply = IPool(pool).totalTCO2Supply();
        return totalSupply;
    }

    /// @notice Calculates the ratios for deposit fee calculation.
    /// @param amount The amount to be deposited.
    /// @param current The current balance of the pool.
    /// @param total The total supply of the pool.
    /// @return The calculated ratios.
    function getRatiosDeposit(SD59x18 amount, SD59x18 current, SD59x18 total) private view returns (SD59x18, SD59x18) {
        SD59x18 a = total == zero ? zero : current / total;
        SD59x18 b = (current + amount) / (total + amount);

        return (a, b);
    }

    /// @notice Calculates the ratios for redemption fee calculation.
    /// @param amount The amount to be redeemed.
    /// @param current The current balance of the pool.
    /// @param total The total supply of the pool.
    /// @return The calculated ratios.
    function getRatiosRedemption(SD59x18 amount, SD59x18 current, SD59x18 total)
        private
        view
        returns (SD59x18, SD59x18)
    {
        SD59x18 a = total == zero ? zero : current / total;
        SD59x18 b = (total - amount) == zero ? zero : (current - amount) / (total - amount);

        return (a, b);
    }

    /// @notice Calculates the deposit fee for a given amount.
    /// @param amount The amount to be deposited.
    /// @param current The current balance of the pool.
    /// @param total The total supply of the pool.
    /// @return The calculated deposit fee.
    function getDepositFee(uint256 amount, uint256 current, uint256 total) private view returns (uint256) {
        require(
            total >= current,
            "The total volume in the pool must be greater than or equal to the volume for an individual asset"
        );

        SD59x18 amount_float = sd(int256(amount));

        if (
            current == total //single asset (or no assets) special case
        ) {
            return intoUint256(amount_float * singleAssetDepositRelativeFee);
        }

        SD59x18 ta = sd(int256(current));
        SD59x18 tb = ta + amount_float;

        (SD59x18 da, SD59x18 db) = getRatiosDeposit(amount_float, ta, sd(int256(total)));

        require(db * depositFeeRatioScale < one, "Deposit outside range");

        SD59x18 ta_log_a = ta * (one - da * depositFeeRatioScale).log10();
        SD59x18 tb_log_b = tb * (one - db * depositFeeRatioScale).log10();

        SD59x18 fee_float = depositFeeScale * (ta_log_a - tb_log_b);

        uint256 fee = intoUint256(fee_float);
        return fee;
    }

    /// @notice Calculates the redemption fee for a given amount.
    /// @param amount The amount to be redeemed.
    /// @param current The current balance of the pool.
    /// @param total The total supply of the pool.
    /// @return The calculated redemption fee.
    function getRedemptionFee(uint256 amount, uint256 current, uint256 total) private view returns (uint256) {
        require(
            total >= current,
            "The total volume in the pool must be greater than or equal to the volume for an individual asset"
        );
        require(amount <= current, "The amount to be redeemed cannot exceed the current balance of the pool");

        SD59x18 amount_float = sd(int256(amount));

        if (
            current == total //single asset (or no assets) special case
        ) {
            uint256 fee = intoUint256(amount_float * (singleAssetRedemptionRelativeFee));
            return fee;
        }

        SD59x18 ta = sd(int256(current));
        SD59x18 tb = ta - amount_float;

        (SD59x18 da, SD59x18 db) = getRatiosRedemption(amount_float, ta, sd(int256(total)));

        //redemption_fee = scale * (tb * log10(b+shift) - ta * log10(a+shift)) + constant*amount;
        SD59x18 i_a = ta * (da + redemptionFeeShift).log10();
        SD59x18 i_b = tb * (db + redemptionFeeShift).log10();
        SD59x18 fee_float = redemptionFeeScale * (i_b - i_a) + redemptionFeeConstant() * amount_float;

        /*
        @dev
             The fee becomes negative if the amount is too small in comparison to the pool's size.
             In such cases, we apply the dustAssetRedemptionRelativeFee, which is currently set at 30%.
             This represents the maximum fee for the redemption function.
             This measure protects against scenarios where the sum of multiple extremely small redemptions could deplete the pool at a discounted rate.

             Case exists only if asset pool domination is > 90% and amount is ~1e-18 of that asset in the pool
        */
        if (fee_float < zero) {
            return intoUint256(amount_float * dustAssetRedemptionRelativeFee);
        }

        return intoUint256(fee_float);
    }

    /// @notice Returns the current fee setup.
    /// @return recipients shares The fee recipients and their share of the total fee.
    function getFeeSetup() external view returns (address[] memory recipients, uint256[] memory shares) {
        recipients = _recipients;
        shares = _shares;
    }
}
