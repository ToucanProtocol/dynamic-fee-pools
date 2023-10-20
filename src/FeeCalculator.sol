pragma solidity ^0.8.13;

import "./interfaces/IDepositFeeCalculator.sol";
import "./interfaces/IRedemptionFeeCalculator.sol";
import "./interfaces/IPool.sol";

contract FeeCalculator is IDepositFeeCalculator, IRedemptionFeeCalculator {

    uint256 private constant ratioDenominator = 1e3;
    uint256 private constant tokenDenominator = 1e18;

    function calculateDepositFees(address tco2, address pool, uint256 depositAmount) external override returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens) {
        recipients = new address[](1);
        recipients[0] = tco2;
        feesDenominatedInPoolTokens = new uint256[](1);
        feesDenominatedInPoolTokens[0] = getDepositFee(depositAmount, getTokenBalance(pool, tco2), getTotalSupply(pool));
    }

    function calculateRedemptionFee(address tco2, address pool, uint256 depositAmount) external override returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens) {
        recipients = new address[](1);
        recipients[0] = tco2;
        feesDenominatedInPoolTokens = new uint256[](1);
        feesDenominatedInPoolTokens[0] = depositAmount / 100;
    }

    function getTokenBalance(address pool, address tco2) private view returns (uint256) {
        IPool poolInstance = IPool(pool);
        uint256 tokenBalance = poolInstance.tokenBalances(tco2);
        return tokenBalance;
    }

    function getTotalSupply(address pool) private view returns (uint256) {
        IPool poolInstance = IPool(pool);
        uint256 totalSupply = poolInstance.totalSupply();
        return totalSupply;
    }

    function getRatios(uint256 amount, uint256 current, uint256 total) private pure returns (uint256, uint256)
    {
        uint256 a = total == 0 ? 0 : (ratioDenominator * current) / total;
        uint256 b = (total + amount) == 0 ? 0 : (ratioDenominator * (current + amount)) / (total + amount);
        return (a, b);
    }

    function calculateDepositFee(uint256 a, uint256 b, uint256 amount) private pure returns (uint256) {
        uint256 scale = 3;

        uint256 relativeFee = scale * (b**4 - a**4) / (b-a) / 4;
        uint256 relativeFeeDenominator = ratioDenominator**3;
        uint256 relativeFeeCap = 3*relativeFeeDenominator/4;

        if (relativeFee > relativeFeeCap) // cap the fee at 3/4
        {
            relativeFeeCap = relativeFeeCap;
        }

        uint256 fee = (relativeFee * amount) / relativeFeeDenominator;

        return fee;
    }

    function getDepositFee(uint256 amount, uint256 current, uint256 total) private pure returns (uint256) {
        (uint256 a, uint256 b) = getRatios(amount, current, total);
        uint256 fee = calculateDepositFee(a, b, amount);
        return fee;
    }

    function getRedemptionFee(uint256 amount, uint256 current, uint256 total) private pure returns (uint256) {
        //TODO: implement redemption
        return 0;
    }
}
