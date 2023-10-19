pragma solidity ^0.8.13;

interface IRedemptionFeeCalculator {
    function calculateRedemptionFee(address tco2, address pool, uint256 depositAmount) external returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens);
}
