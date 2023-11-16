pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "./interfaces/IDepositFeeCalculator.sol";
import "./interfaces/IRedemptionFeeCalculator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18, ud, intoUint256 } from "@prb/math/src/UD60x18.sol";

contract FeeCalculator is IDepositFeeCalculator, IRedemptionFeeCalculator {

    uint256 private depositFeeScale = 2;

    UD60x18 private zero = ud(0);
    UD60x18 private one = ud(1e18);

    UD60x18 private redemptionFeeScale = ud(0.3 * 1e18);
    UD60x18 private redemptionFeeShift = ud(0.1 * 1e18);//-log10(0+0.1)=1 -> 10^-1
    UD60x18 private redemptionFeeConstant = redemptionFeeScale.mul((one+redemptionFeeShift).log10()); //0.0413926851582251=log10(1+0.1)

    uint256 private constant tokenDenominator = 1e18;
    uint256 private constant ratioDenominator = 1e12;
    uint256 private constant relativeFeeDenominator = ratioDenominator**3;

    function setDepositFeeScale(uint256 _depositFeeScale) public {
        depositFeeScale = _depositFeeScale;
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

    function getRedemptionFee(uint256 amount, uint256 current, uint256 total) private view returns (uint256) {
        require(total >= current);
        require(amount <= current);

        (uint256 a, uint256 b) = getRatios(amount, current, total, false);

        UD60x18 da = ud(a * (1e18 / ratioDenominator));
        UD60x18 db = ud(b * (1e18 / ratioDenominator));

        UD60x18 ta = ud(current);
        UD60x18 tb = ud(current - amount);

        UD60x18 shifted_da = da + redemptionFeeShift;
        UD60x18 shifted_db = db + redemptionFeeShift;

        bool is_log_a_negative = shifted_da < one;
        bool is_log_b_negative = shifted_db < one;

        //used this property: `log_b(a) = -log_b(1/a)` to not use negative values
        UD60x18 positive_log_a = da == zero ? zero : (is_log_a_negative==true ? (one / shifted_da) : shifted_da).log10();
        UD60x18 positive_log_b = db == zero ? zero : (is_log_b_negative==true ? (one / shifted_db) : shifted_db).log10();

        //redemption_fee = scale * (tb * log10(b+shift) - ta * log10(a+shift)) + constant*amount;
        UD60x18 fee_float = redemptionFeeConstant.mul(ud(amount)); //we start with always positive constant

        UD60x18 feeVariablePartA = redemptionFeeScale.mul(ta.mul(positive_log_a));
        UD60x18 feeVariablePartB = redemptionFeeScale.mul(tb.mul(positive_log_b));

        if(!is_log_a_negative)
            fee_float = fee_float + feeVariablePartA;
        if(!is_log_b_negative)
            fee_float = fee_float + feeVariablePartB;

        if(is_log_a_negative)
        {
            if(feeVariablePartA > fee_float)
            {
                if(feeVariablePartA == fee_float + ud(1))
                    fee_float = fee_float + ud(1);
                else
                    console.log("feeVariablePartA > fee_float:\n%d\n>\n%d", intoUint256(feeVariablePartA), intoUint256(fee_float));
            }
            fee_float = fee_float - feeVariablePartA;
        }

        if(is_log_b_negative)
        {
            if(feeVariablePartB > fee_float)
            {
                if(feeVariablePartB == fee_float + ud(1))
                    fee_float = fee_float + ud(1);
                else
                    console.log("feeVariablePartB > fee_float:\n%d\n>\n%d", intoUint256(feeVariablePartB), intoUint256(fee_float));
            }

            fee_float = fee_float - feeVariablePartB;
        }

        uint256 fee = intoUint256(fee_float);

        if(fee > amount)
        {
            console.log("Fee > amount:\n%d\n>\n%d", fee, amount);
            require(fee <= amount, "Fee must be lower or equal to redemption amount");
        }

        return fee;
    }
}
