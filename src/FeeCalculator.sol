pragma solidity ^0.8.13;

import "./interfaces/IDepositFeeCalculator.sol";
import "./interfaces/IRedemptionFeeCalculator.sol";

contract FeeCalculator is IDepositFeeCalculator, IRedemptionFeeCalculator {
    function calculateDepositFees(address tco2, address pool, uint256 depositAmount) external override returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens) {
        recipients = new address[](1);
        recipients[0] = tco2;
        feesDenominatedInPoolTokens = new uint256[](1);
        feesDenominatedInPoolTokens[0] = depositAmount / 100;
    }

    function calculateRedemptionFee(address tco2, address pool, uint256 depositAmount) external override returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens) {
        recipients = new address[](1);
        recipients[0] = tco2;
        feesDenominatedInPoolTokens = new uint256[](1);
        feesDenominatedInPoolTokens[0] = depositAmount / 100;
    }
}
