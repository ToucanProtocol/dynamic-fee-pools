pragma solidity ^0.8.13;

import "./interfaces/IDepositFeeCalculator.sol";
import "./interfaces/IRedemptionFeeCalculator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeeCalculator is IDepositFeeCalculator, IRedemptionFeeCalculator {

    uint256 private depositFeeScale = 2;
    uint256 private redemptionFeeDivider = 3;
    uint256 private constant tokenDenominator = 1e18;
    uint256 private constant ratioDenominator = 1e12;
    uint256 private constant relativeFeeDenominator = ratioDenominator**3;

    function setDepositFeeScale(uint256 _depositFeeScale) public {
        depositFeeScale = _depositFeeScale;
    }

    function setRedemptionFeeDivider(uint256 _redemptionFeeDivider) public {
        redemptionFeeDivider = _redemptionFeeDivider;
    }

    address[] private _recipients;
    uint256[] private _shares;

    function feeSetup(address[] memory recipients, uint256[] memory shares) external {
        require(recipients.length == shares.length, "Recipients and shares arrays must have the same length");
        require(recipients.length > 0, "Recipients and shares arrays must not be empty");

        uint256 totalShares = 0;
        for (uint i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }
        require(totalShares == 100, "Total shares must equal 100");

        _recipients = recipients;
        _shares = shares;
    }

    function calculateDepositFees(address tco2, address pool, uint256 depositAmount) external override returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens) {
        uint256 totalFee = getDepositFee(depositAmount, getTokenBalance(pool, tco2), getTotalSupply(pool));
        return distributeFeeAmongShares(totalFee);
    }

    function distributeFeeAmongShares(uint256 totalFee) private view returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens) {
        recipients = new address[](_recipients.length);
        feesDenominatedInPoolTokens = new uint256[](_recipients.length);

        uint256 restFee = totalFee;

        for (uint i=0; i<_recipients.length; i++) {
            recipients[i] = _recipients[i];
            feesDenominatedInPoolTokens[i] = (totalFee * _shares[i]) / 100;
            restFee -= feesDenominatedInPoolTokens[i];
        }

        require(restFee >=0);
        feesDenominatedInPoolTokens[0] += restFee;//we give rest of the fee (if any) to the first recipient
    }

    function calculateRedemptionFee(address tco2, address pool, uint256 depositAmount) external override returns (address[] memory recipients, uint256[] memory feesDenominatedInPoolTokens) {
        uint256 totalFee = getRedemptionFee(depositAmount, getTokenBalance(pool, tco2), getTotalSupply(pool));
        return distributeFeeAmongShares(totalFee);
    }

    function getTokenBalance(address pool, address tco2) private view returns (uint256) {
        uint256 tokenBalance = IERC20(tco2).balanceOf(pool);
        return tokenBalance;
    }

    function getTotalSupply(address pool) private view returns (uint256) {
        uint256 totalSupply = IERC20(pool).totalSupply();
        return totalSupply;
    }

    function getRatios(uint256 amount, uint256 current, uint256 total, bool isDeposit) private pure returns (uint256, uint256)
    {
        uint256 a = total == 0 ? 0 : (ratioDenominator * current) / total;
        uint256 b;
        if(isDeposit)
            b = (total + amount) == 0 ? 0 : (ratioDenominator * (current + amount)) / (total + amount);
        else
            b = (total - amount) == 0 ? 0 : (ratioDenominator * (current - amount)) / (total - amount);
        return (a, b);
    }

    function calculateDepositFee(uint256 a, uint256 b, uint256 amount) private view returns (uint256) {
        require(b > a, "b should be greater than a");

        uint256 relativeFee = depositFeeScale * (b**4 - a**4) / (b-a) / 4;
        uint256 fee = (relativeFee * amount) / relativeFeeDenominator;
        require(fee <= amount, "Fee must be lower or equal to deposit amount");
        return fee;
    }

    function getDepositFee(uint256 amount, uint256 current, uint256 total) private view returns (uint256) {
        require(total >= current);

        (uint256 a, uint256 b) = getRatios(amount, current, total, true);
        uint256 fee = calculateDepositFee(a, b, amount);
        return fee;
    }

    function calculateRedemptionFee(uint256 a, uint256 b, uint256 amount) private view returns (uint256) {
        uint256 relativeFee = (ratioDenominator-b)**3 / redemptionFeeDivider;//pow(1-b, 3)/3
        uint256 fee = (relativeFee * amount) / relativeFeeDenominator;
        require(fee <= amount, "Fee must be lower or equal to redemption amount");
        return fee;
    }

    function getRedemptionFee(uint256 amount, uint256 current, uint256 total) private view returns (uint256) {
        require(total >= current);
        require(amount <= current);

        (uint256 a, uint256 b) = getRatios(amount, current, total, false);
        uint256 fee = calculateRedemptionFee(a, b, amount);
        return fee;
    }
}
