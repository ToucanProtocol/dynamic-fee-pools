pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "./interfaces/IDepositFeeCalculator.sol";
import "./interfaces/IRedemptionFeeCalculator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UD60x18, ud, intoUint256 } from "@prb/math/src/UD60x18.sol";
import { SD59x18, sd, intoUint256, convert } from "@prb/math/src/SD59x18.sol";

contract FeeCalculator is IDepositFeeCalculator, IRedemptionFeeCalculator {

    UD60x18 private zero = ud(0);
    UD60x18 private one = ud(1e18);

    SD59x18 private zero_signed = sd(0);
    SD59x18 private one_signed = sd(1e18);

    UD60x18 private depositFeeScale = ud(0.18 * 1e18);
    UD60x18 private depositFeeRatioScale = ud(0.99 * 1e18);

    SD59x18 private redemptionFeeScale = sd(0.3 * 1e18);
    SD59x18 private redemptionFeeShift = sd(0.1 * 1e18);//-log10(0+0.1)=1 -> 10^-1
    SD59x18 private redemptionFeeConstant = redemptionFeeScale.mul((one_signed+redemptionFeeShift).log10()); //0.0413926851582251=log10(1+0.1)

    uint256 private constant tokenDenominator = 1e18;
    uint256 private constant ratioDenominator = 1e12;
    uint256 private constant relativeFeeDenominator = ratioDenominator**3;

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

    function getRatiosDeposit(UD60x18 amount, UD60x18 current, UD60x18 total) private view returns (UD60x18, UD60x18)
    {
        UD60x18 a = total == zero ? zero : current / total;
        UD60x18 b = (total + amount) == zero ? zero : (current + amount) / (total + amount);

        return (a, b);
    }

    function getRatiosRedemption(SD59x18 amount, SD59x18 current, SD59x18 total) private view returns (SD59x18, SD59x18)
    {
        SD59x18 a = total == zero_signed ? zero_signed : current / total;
        SD59x18 b = (total - amount) == zero_signed ? zero_signed : (current - amount) / (total - amount);

        return (a, b);
    }

    function getDepositFee(uint256 amount, uint256 current, uint256 total) private view returns (uint256) {
        require(total >= current);

        UD60x18 amount_float = ud(amount);
        UD60x18 ta = ud(current);
        UD60x18 tb = ta + amount_float;

        (UD60x18 da, UD60x18 db) = getRatiosDeposit(amount_float, ta, ud(total));

        //(log10(1 - a * N)*ta - log10(1 - b * N)*tb) * M
        //used this property: `log_b(a) = -log_b(1/a)` to not use negative values

        UD60x18 one_minus_a = one - da.mul(depositFeeRatioScale);
        UD60x18 one_minus_b = one - db.mul(depositFeeRatioScale);

        UD60x18 ta_log_a = ta.mul(one_minus_a.inv().log10());
        UD60x18 tb_log_b = tb.mul(one_minus_b.inv().log10());

        UD60x18 fee_float;

        if(tb_log_b > ta_log_a)
            fee_float = depositFeeScale.mul(tb_log_b - ta_log_a);
        else
            fee_float = depositFeeScale.mul(ta_log_a - tb_log_b);

        uint256 fee = intoUint256(fee_float);

        if(fee > amount)
        {
            console.log("Fee > amount:\n%d\n>\n%d", fee, amount);
            require(fee <= amount, "Fee must be lower or equal to deposit amount");
        }

        require(fee > 0, "Fee must be greater than 0");
        return fee;
    }

    function getRedemptionFee(uint256 amount, uint256 current, uint256 total) private view returns (uint256) {
        require(total >= current);
        require(amount <= current);

        SD59x18 amount_float = sd(int256(amount));
        SD59x18 ta = sd(int256(current));
        SD59x18 tb = ta - amount_float;

        (SD59x18 da, SD59x18 db) = getRatiosRedemption(amount_float, ta, sd(int256(total)));

        //redemption_fee = scale * (tb * log10(b+shift) - ta * log10(a+shift)) + constant*amount;


        SD59x18 i_a = ta.mul(da.add(redemptionFeeShift).log10());
        SD59x18 i_b = tb.mul(db.add(redemptionFeeShift).log10());
        SD59x18 fee_float = redemptionFeeScale.mul(i_b.sub(i_a)).add(redemptionFeeConstant*amount_float);

        if(fee_float < zero_signed)
        {
            if(fee_float / amount_float < sd(1e-6 * 1e18))
                //fee_float=zero_signed;//if the fee is negative but is less than 0.0001% of amount than it's basically 0
                require(fee_float > zero_signed, "Fee must be greater than 0");
            else
                require(fee_float > zero_signed, "Total failure. Fee must be greater than 0 or at least close to it.");
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
