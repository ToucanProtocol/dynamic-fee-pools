pragma solidity ^0.8.13;

import "./interfaces/IDepositFeeCalculator.sol";
import "./interfaces/IRedemptionFeeCalculator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeeCalculator is IDepositFeeCalculator, IRedemptionFeeCalculator {

    uint256 private constant depositFeeScale = 3;
    uint256 private constant tokenDenominator = 1e18;
    uint256 private constant ratioDenominator = 1e12;
    uint256 private constant relativeFeeDenominator = ratioDenominator**3;
    uint256 private constant relativeFeeCap = 3*relativeFeeDenominator/4;

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
        uint256 tokenBalance = IERC20(tco2).balanceOf(pool);
        return tokenBalance;
    }

    function getTotalSupply(address pool) private view returns (uint256) {
        uint256 totalSupply = IERC20(pool).totalSupply();
        return totalSupply;
    }

    function getRatios(uint256 amount, uint256 current, uint256 total) private pure returns (uint256, uint256)
    {
        uint256 a = total == 0 ? 0 : (ratioDenominator * current) / total;
        uint256 b = (total + amount) == 0 ? 0 : (ratioDenominator * (current + amount)) / (total + amount);
        return (a, b);
    }

    function calculateDepositFee(uint256 a, uint256 b, uint256 amount) private pure returns (uint256) {
        uint256 relativeFee = b-a==0 ? relativeFeeCap : depositFeeScale * (b**4 - a**4) / (b-a) / 4;

        if (relativeFee > relativeFeeCap) // cap the fee at 3/4
        {
            relativeFee = relativeFeeCap;
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
