// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <security@toucan.earth> or visit security.toucan.earth
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {SD59x18, sd, intoUint256} from "@prb/math/src/SD59x18.sol";

import {IFeeCalculator, FeeDistribution} from "./interfaces/IFeeCalculator.sol";
import "./interfaces/IPool.sol";

/// @title FeeCalculator
/// @author Neutral Labs Inc. & Toucan Protocol
/// @notice This contract calculates deposit and redemption fees for a given pool.
/// @dev It implements the IFeeCalculator interface.
contract FeeCalculator is IFeeCalculator, Ownable {
    /// @dev Version-related parameters. VERSION keeps track of production
    /// releases. VERSION_RELEASE_CANDIDATE keeps track of iterations
    /// of a VERSION in our staging environment.
    string public constant VERSION = "1.2.0";
    uint256 public constant VERSION_RELEASE_CANDIDATE = 1;

    SD59x18 private _zero = sd(0);
    SD59x18 private _one = sd(1e18);

    SD59x18 public depositFeeScale = sd(0.18 * 1e18);
    SD59x18 public depositFeeRatioScale = sd(0.99 * 1e18);
    SD59x18 public singleAssetDepositRelativeFee = sd(0.1 * 1e18);

    SD59x18 public redemptionFeeScale = sd(0.3 * 1e18);
    SD59x18 public redemptionFeeShift = sd(0.1 * 1e18); //-log10(0+0.1)=1 -> 10^-1

    function redemptionFeeConstant() public view returns (SD59x18) {
        return redemptionFeeScale * (_one + redemptionFeeShift).log10(); //0.0413926851582251=log10(1+0.1)
    }

    SD59x18 public singleAssetRedemptionRelativeFee = sd(0.1 * 1e18);
    SD59x18 public dustAssetRedemptionRelativeFee = sd(0.3 * 1e18);

    address[] private _recipients;
    uint256[] private _shares;

    event DepositFeeScaleUpdated(int256 depositFeeScale);
    event DepositFeeRatioUpdated(int256 depositFeeRatioScale);
    event SingleAssetDepositRelativeFeeUpdated(int256 singleAssetDepositRelativeFee);
    event RedemptionFeeScaleUpdated(int256 redemptionFeeScale);
    event RedemptionFeeShift(int256 redemptionFeeShift);
    event SingleAssetRedemptionRelativeFeeUpdated(int256 singleAssetRedemptionRelativeFee);
    event DustAssetRedemptionRelativeFeeUpdated(int256 dustAssetRedemptionRelativeFee);
    event FeeSetup(address[] recipients, uint256[] shares);

    constructor() Ownable() {}

    /// @notice Sets the deposit fee scale.
    /// @dev Can only be called by the current owner.
    /// @param _depositFeeScale The new deposit fee scale.
    function setDepositFeeScale(int256 _depositFeeScale) external onlyOwner {
        SD59x18 depositFeeScaleSD = sd(_depositFeeScale);
        require(depositFeeScaleSD >= _zero && depositFeeScaleSD <= _one, "Deposit fee scale must be between 0 and 1");
        depositFeeScale = depositFeeScaleSD;
        emit DepositFeeScaleUpdated(_depositFeeScale);
    }

    /// @notice Sets the deposit fee ratio scale.
    /// @dev Can only be called by the current owner.
    /// @param _depositFeeRatioScale The new deposit fee ratio scale.
    function setDepositFeeRatioScale(int256 _depositFeeRatioScale) external onlyOwner {
        SD59x18 depositFeeRatioScaleSD = sd(_depositFeeRatioScale);
        require(depositFeeRatioScaleSD >= _zero, "Deposit fee ratio scale must be above 0");
        depositFeeRatioScale = depositFeeRatioScaleSD;
        emit DepositFeeRatioUpdated(_depositFeeRatioScale);
    }

    /// @notice Sets the single asset deposit relative fee.
    /// @dev Can only be called by the current owner.
    /// @param _singleAssetDepositRelativeFee The new single asset deposit relative fee.
    function setSingleAssetDepositRelativeFee(int256 _singleAssetDepositRelativeFee) external onlyOwner {
        SD59x18 singleAssetDepositRelativeFeeSD = sd(_singleAssetDepositRelativeFee);
        require(
            singleAssetDepositRelativeFeeSD >= _zero && singleAssetDepositRelativeFeeSD <= _one,
            "Single asset deposit relative fee must be between 0 and 1"
        );
        singleAssetDepositRelativeFee = singleAssetDepositRelativeFeeSD;
        emit SingleAssetDepositRelativeFeeUpdated(_singleAssetDepositRelativeFee);
    }

    /// @notice Sets the redemption fee scale.
    /// @dev Can only be called by the current owner.
    /// @param _redemptionFeeScale The new redemption fee scale.
    function setRedemptionFeeScale(int256 _redemptionFeeScale) external onlyOwner {
        SD59x18 redemptionFeeScaleSD = sd(_redemptionFeeScale);
        require(
            redemptionFeeScaleSD >= _zero && redemptionFeeScaleSD <= _one,
            "Redemption fee scale must be between 0 and 1"
        );
        redemptionFeeScale = redemptionFeeScaleSD;
        emit RedemptionFeeScaleUpdated(_redemptionFeeScale);
    }

    /// @notice Sets the redemption fee shift.
    /// @dev Can only be called by the current owner.
    /// @param _redemptionFeeShift The new redemption fee shift.
    function setRedemptionFeeShift(int256 _redemptionFeeShift) external onlyOwner {
        SD59x18 redemptionFeeShiftSD = sd(_redemptionFeeShift);
        require(
            redemptionFeeShiftSD >= _zero && redemptionFeeShiftSD <= _one,
            "Redemption fee shift must be between 0 and 1"
        );
        redemptionFeeShift = redemptionFeeShiftSD;
        emit RedemptionFeeShift(_redemptionFeeShift);
    }

    /// @notice Sets the single asset redemption relative fee.
    /// @dev Can only be called by the current owner.
    /// @param _singleAssetRedemptionRelativeFee The new single asset redemption relative fee.
    function setSingleAssetRedemptionRelativeFee(int256 _singleAssetRedemptionRelativeFee) external onlyOwner {
        SD59x18 singleAssetRedemptionRelativeFeeSD = sd(_singleAssetRedemptionRelativeFee);
        require(
            singleAssetRedemptionRelativeFeeSD >= _zero && singleAssetRedemptionRelativeFeeSD <= _one,
            "Single asset redemption relative fee must be between 0 and 1"
        );
        singleAssetRedemptionRelativeFee = singleAssetRedemptionRelativeFeeSD;
        emit SingleAssetRedemptionRelativeFeeUpdated(_singleAssetRedemptionRelativeFee);
    }

    /// @notice Sets the dust asset redemption relative fee.
    /// @dev Can only be called by the current owner.
    /// @param _dustAssetRedemptionRelativeFee The new dust asset redemption relative fee.
    function setDustAssetRedemptionRelativeFee(int256 _dustAssetRedemptionRelativeFee) external onlyOwner {
        SD59x18 dustAssetRedemptionRelativeFeeSD = sd(_dustAssetRedemptionRelativeFee);
        require(
            dustAssetRedemptionRelativeFeeSD >= _zero && dustAssetRedemptionRelativeFeeSD <= _one,
            "Dust asset redemption relative fee must be between 0 and 1"
        );
        dustAssetRedemptionRelativeFee = dustAssetRedemptionRelativeFeeSD;
        emit DustAssetRedemptionRelativeFeeUpdated(_dustAssetRedemptionRelativeFee);
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
        emit FeeSetup(recipients, shares);
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
        feeDistribution =
            _calculateFee(depositAmount, IPool(pool).totalPerProjectSupply(tco2), _getTotalSupply(pool), _getDepositFee);
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

        feeDistribution = _calculateFee(
            redemptionAmount, IPool(pool).totalPerProjectSupply(tco2), _getTotalSupply(pool), _getRedemptionFee
        );
    }

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
        override
        returns (FeeDistribution memory feeDistribution)
    {
        feeDistribution = _calculateFee(
            depositAmount, IPool(pool).totalPerProjectSupply(erc1155, tokenId), _getTotalSupply(pool), _getDepositFee
        );
    }

    /// @notice Calculates the redemption fees for a given amount on ERC1155 projects.
    /// @param pool The address of the pool.
    /// @param erc1155s The addresses of the ERC1155 projects.
    /// @param tokenIds The tokenIds of the project vintages.
    /// @param redemptionAmounts The amounts to be redeemed.
    /// @return feeDistribution How the fee is meant to be
    /// distributed among the fee recipients.
    function calculateRedemptionFees(
        address pool,
        address[] calldata erc1155s,
        uint256[] calldata tokenIds,
        uint256[] calldata redemptionAmounts
    ) external view override returns (FeeDistribution memory feeDistribution) {
        require(erc1155s.length == tokenIds.length, "erc1155s/tokenIds length mismatch");
        require(erc1155s.length == redemptionAmounts.length, "erc1155s/redemptionAmounts length mismatch");
        require(erc1155s.length == 1, "only one");
        address erc1155 = erc1155s[0];
        uint256 tokenId = tokenIds[0];
        uint256 redemptionAmount = redemptionAmounts[0];

        feeDistribution = _calculateFee(
            redemptionAmount,
            IPool(pool).totalPerProjectSupply(erc1155, tokenId),
            _getTotalSupply(pool),
            _getRedemptionFee
        );
    }

    /// @notice Returns the current fee setup.
    /// @return recipients shares The fee recipients and their share of the total fee.
    function getFeeSetup() external view returns (address[] memory recipients, uint256[] memory shares) {
        recipients = _recipients;
        shares = _shares;
    }

    /// @notice Gets the total supply of a given pool.
    /// @param pool The address of the pool.
    /// @return The total supply of the pool.
    function _getTotalSupply(address pool) private view returns (uint256) {
        uint256 totalSupply = IPool(pool).totalTCO2Supply();
        return totalSupply;
    }

    /// @notice Calculates the ratios for deposit fee calculation.
    /// @param amount The amount to be deposited.
    /// @param current The current balance of the pool.
    /// @param total The total supply of the pool.
    /// @return The current and resulting ratios of the asset in the pool
    /// before and after the deposit.
    function _getRatiosDeposit(SD59x18 amount, SD59x18 current, SD59x18 total)
        private
        view
        returns (SD59x18, SD59x18)
    {
        SD59x18 currentRatio = total == _zero ? _zero : current / total;
        SD59x18 resultingRatio = (current + amount) / (total + amount);

        return (currentRatio, resultingRatio);
    }

    /// @notice Calculates the ratios for redemption fee calculation.
    /// @param amount The amount to be redeemed.
    /// @param current The current balance of the pool.
    /// @param total The total supply of the pool.
    /// @return The current and resulting ratios of the asset in the pool
    /// before and after the redemption.
    function _getRatiosRedemption(SD59x18 amount, SD59x18 current, SD59x18 total)
        private
        view
        returns (SD59x18, SD59x18)
    {
        SD59x18 currentRatio = total == _zero ? _zero : current / total;
        SD59x18 resultingRatio = (total - amount) == _zero ? _zero : (current - amount) / (total - amount);

        return (currentRatio, resultingRatio);
    }

    /// @notice Calculates the deposit fee for a given amount.
    /// @param amount The amount to be deposited.
    /// @param current The current balance of the pool.
    /// @param total The total supply of the pool.
    /// @return The calculated deposit fee.
    function _getDepositFee(uint256 amount, uint256 current, uint256 total) private view returns (uint256) {
        require(
            total >= current,
            "The total volume in the pool must be greater than or equal to the volume for an individual asset"
        );

        SD59x18 amountSD = sd(int256(amount));

        if (
            current == total //single asset (or no assets) special case
        ) {
            return intoUint256(amountSD * singleAssetDepositRelativeFee);
        }

        SD59x18 currentSD = sd(int256(current));
        SD59x18 resultingSD = currentSD + amountSD;

        (SD59x18 currentRatio, SD59x18 resultingRatio) = _getRatiosDeposit(amountSD, currentSD, sd(int256(total)));

        require(resultingRatio * depositFeeRatioScale < _one, "Deposit outside range");

        SD59x18 currentLog = currentSD * (_one - currentRatio * depositFeeRatioScale).log10();
        SD59x18 resultingLog = resultingSD * (_one - resultingRatio * depositFeeRatioScale).log10();

        SD59x18 feeSD = depositFeeScale * (currentLog - resultingLog);

        uint256 fee = intoUint256(feeSD);
        return fee;
    }

    /// @notice Calculates the redemption fee for a given amount.
    /// @param amount The amount to be redeemed.
    /// @param current The current balance of the pool.
    /// @param total The total supply of the pool.
    /// @return The calculated redemption fee.
    function _getRedemptionFee(uint256 amount, uint256 current, uint256 total) private view returns (uint256) {
        require(
            total >= current,
            "The total volume in the pool must be greater than or equal to the volume for an individual asset"
        );
        require(amount <= current, "The amount to be redeemed cannot exceed the current balance of the pool");

        SD59x18 amountSD = sd(int256(amount));

        if (
            current == total //single asset (or no assets) special case
        ) {
            uint256 fee = intoUint256(amountSD * (singleAssetRedemptionRelativeFee));
            return fee;
        }

        SD59x18 currentSD = sd(int256(current));
        SD59x18 resultingSD = currentSD - amountSD;

        (SD59x18 currentRatio, SD59x18 resultingRatio) = _getRatiosRedemption(amountSD, currentSD, sd(int256(total)));

        //redemption_fee = scale * (resultingSD * log10(b+shift) - currentSD * log10(a+shift)) + constant*amount;
        SD59x18 currentLog = currentSD * (currentRatio + redemptionFeeShift).log10();
        SD59x18 resultingLog = resultingSD * (resultingRatio + redemptionFeeShift).log10();
        SD59x18 feeSD = redemptionFeeScale * (resultingLog - currentLog) + redemptionFeeConstant() * amountSD;

        /*
        @dev
             The fee becomes negative if the amount is too small in comparison to the pool's size.
             In such cases, we apply the dustAssetRedemptionRelativeFee, which is currently set at 30%.
             This represents the maximum fee for the redemption function.
             This measure protects against scenarios where the sum of multiple extremely small redemptions could deplete the pool at a discounted rate.

             Case exists only if asset pool domination is > 90% and amount is ~1e-18 of that asset in the pool
        */
        if (feeSD < _zero) {
            return intoUint256(amountSD * dustAssetRedemptionRelativeFee);
        }

        return intoUint256(feeSD);
    }

    function _calculateFee(
        uint256 requestedAmount,
        uint256 projectSupply,
        uint256 totalPoolSupply,
        function(uint256, uint256, uint256) view returns (uint256) calculator
    ) internal view returns (FeeDistribution memory) {
        require(requestedAmount != 0, "requested amount must be > 0");

        uint256 feeAmount = calculator(requestedAmount, projectSupply, totalPoolSupply);

        require(feeAmount <= requestedAmount, "Fee must be lower or equal to requested amount");
        if (feeAmount == 0) {
            return FeeDistribution(new address[](0), new uint256[](0));
        }

        return calculateFeeShares(feeAmount);
    }
}
