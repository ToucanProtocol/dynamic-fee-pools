// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import "./interfaces/IDepositFeeCalculator.sol";
import "./interfaces/IRedemptionFeeCalculator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {SD59x18, sd, intoUint256} from "@prb/math/src/SD59x18.sol";

/// @title FeeCalculator
/// @author Neutral Labs Inc.
/// @notice This contract calculates deposit and redemption fees for a given pool.
/// @dev It implements IDepositFeeCalculator and IRedemptionFeeCalculator interfaces.
contract FeeCalculator is IDepositFeeCalculator, IRedemptionFeeCalculator, Ownable {
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

    constructor() Ownable(msg.sender) {}

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

    /// @notice Calculates the deposit fees for a given amount.
    /// @param tco2 The address of the TCO2 token.
    /// @param pool The address of the pool.
    /// @param depositAmount The amount to be deposited.
    /// @return recipients The addresses of the fee recipients.
    /// @return feesDenominatedInPoolTokens The amount of fees each recipient should receive.
    function calculateDepositFees(address tco2, address pool, uint256 depositAmount)
        external
        view
        override
        returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens)
    {
        require(depositAmount > 0, "depositAmount must be > 0");

        uint256 totalFee = getDepositFee(depositAmount, getTokenBalance(pool, tco2), getTotalSupply(pool));

        require(totalFee <= depositAmount, "Fee must be lower or equal to deposit amount");
        require(totalFee > 0, "Fee must be greater than 0");

        return distributeFeeAmongShares(totalFee);
    }

    /// @notice Distributes the total fee among the recipients according to their shares.
    /// @param totalFee The total fee to be distributed.
    /// @return recipients The addresses of the fee recipients.
    /// @return feesDenominatedInPoolTokens The amount of fees each recipient should receive.
    function distributeFeeAmongShares(uint256 totalFee)
        private
        view
        returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens)
    {
        feesDenominatedInPoolTokens = new uint256[](_recipients.length);

        uint256 restFee = totalFee;

        for (uint256 i = 0; i < _recipients.length; i++) {
            feesDenominatedInPoolTokens[i] = (totalFee * _shares[i]) / 100;
            restFee -= feesDenominatedInPoolTokens[i];
        }

        recipients = _recipients;
        feesDenominatedInPoolTokens[0] += restFee; //we give rest of the fee (if any) to the first recipient
    }

    /// @notice Calculates the redemption fees for a given amount.
    /// @param tco2 The address of the TCO2 token.
    /// @param pool The address of the pool.
    /// @param redemptionAmount The amount to be redeemed.
    /// @return recipients The addresses of the fee recipients.
    /// @return feesDenominatedInPoolTokens The amount of fees each recipient should receive.
    function calculateRedemptionFees(address tco2, address pool, uint256 redemptionAmount)
        external
        view
        override
        returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens)
    {
        require(redemptionAmount > 0, "redemptionAmount must be > 0");

        uint256 totalFee = getRedemptionFee(redemptionAmount, getTokenBalance(pool, tco2), getTotalSupply(pool));

        require(totalFee <= redemptionAmount, "Fee must be lower or equal to redemption amount");
        require(totalFee > 0, "Fee must be greater than 0");

        return distributeFeeAmongShares(totalFee);
    }

    /// @notice Calculates the redemption fees across multiple TCO2s for a given amount.
    /// @param tco2s The addresses of the TCO2 tokens.
    /// @param pool The address of the pool.
    /// @param amounts The amounts to be redeemed per TCO2.
    /// @return recipients The addresses of the fee recipients.
    /// @return feesDenominatedInPoolTokens The amount of fees each recipient should receive.
    function calculateRedemptionFeesMany(address[] calldata tco2s, address pool, uint256[] calldata amounts)
        external
        view
        override
        returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens)
    {
        uint256 tco2Len = tco2s.length;
        require(tco2Len == amounts.length, "Length mismatch");

        uint256 totalFee = 0;
        uint256 totalPoolSupply = getTotalSupply(pool);

        for (uint256 i = 0; i < tco2Len; ++i) {
            uint256 redemptionAmount = amounts[i];
            require(redemptionAmount > 0, "amount must be > 0");
            uint256 tco2Balance = getTokenBalance(pool, tco2s[i]);
            uint256 feeAmount = getRedemptionFee(redemptionAmount, tco2Balance, totalPoolSupply);
            require(feeAmount <= redemptionAmount, "Fee must be lower or equal to redemption amount");
            totalFee += feeAmount;
            // Update total pool supply to account for the tokens to be burnt
            // so the next iteration charges fees using the intermediate
            // pool supply.
            totalPoolSupply = totalPoolSupply - redemptionAmount + feeAmount;
        }

        require(totalFee > 0, "Fee must be greater than 0");

        return distributeFeeAmongShares(totalFee);
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
        uint256 totalSupply = IERC20(pool).totalSupply();
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
            uint256 fee = intoUint256(amount_float * singleAssetDepositRelativeFee);
            return fee;
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
}
