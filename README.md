<div align="center">

# FeeCalculator :moneybag:

A robust Solidity contract for calculating deposit and redemption fees for a biochar ReFi pool.

[![Solidity](https://img.shields.io/badge/Solidity-^0.8.13-blue.svg)](https://soliditylang.org/)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-Contracts-green.svg)](https://openzeppelin.com/contracts/)
[![PRBMath](https://img.shields.io/badge/PRBMath-Library-orange.svg)](https://github.com/hifi-finance/prb-math)

</div>

## :sparkles: Features

FeeCalculator implements `IDepositFeeCalculator` and `IRedemptionFeeCalculator` interfaces, providing the following features:

- **Fee Distribution:** Set up the fee distribution among recipients.
- **Deposit Fees Calculation:** Calculate the deposit fees for a given amount and distribute the total fee among the recipients according to their shares.
- **Redemption Fees Calculation:** Calculate the redemption fees for a given amount.
- **Pool Information Retrieval:** Get the balance of the TCO2 token in a given pool, and the total supply of a given pool.
- **Ratios Calculation:** Calculate the ratios for deposit and redemption fee calculation.
- **Fee Calculation:** Calculate the deposit and redemption fee for a given amount.

## :hammer_and_wrench: How to Test

Run the following command in your terminal:

```bash
forge test -vv --via-ir
```

# Fee Structure :chart_with_upwards_trend:

The fee function is designed to discourage monopolizing the pool with one asset. It imposes higher fees for deposits of assets that already dominate the pool, and lower fees for deposits of assets that are not in the pool. Conversely, redeeming an asset that monopolizes the pool is cheap, while redeeming an asset that makes up a small percentage of the pool is expensive.

The fee functions for both operations are based on dominance coefficients `a` and `b`, which designate the ratio of how dominant a particular asset is before (`a`) and after (`b`) the operation.

## Single Asset or No Assets in the Pool
In the case where there is only one asset in the pool or the pool is empty, the fee structure is simplified to a flat rate. This is designed to encourage diversification in the pool and discourage monopolization by a single asset.

For both deposit and redemption operations, a flat fee of 10% is applied. This means that regardless of the amount deposited or redeemed, the fee will always be 10% of that amount.
This flat fee structure serves two purposes:
1. Simplicity: It provides a straightforward and predictable fee calculation for users when there is only one asset or no assets in the pool.
2. Encouragement of Diversification: The flat fee encourages users to diversify the assets in the pool. If there are multiple assets in the pool, the fee calculation becomes more complex (as described in the sections below), potentially leading to lower fees for less dominant assets.

Remember, the goal of this fee structure is to maintain a balanced composition in the pool and discourage monopolization by any single asset.

## Mathematical Expressions

### Dominance Coefficients

`a = current_asset_volume / total_pool_volume`

`b = (current_asset_volume +/- deposit/redemption amount ) / (total_pool_volume +/- deposit/redemption amount)`

### Current and Future Amounts of a Particular Asset in the Pool

`ta = current_asset_volume`

`tb = current_asset_volume +/- deposit/redemption amount`

### Fee Function for Deposit

Relative fee values are between 0% (exclusive) and 36% (inclusive).

Functional form for absolute fee is as follows:

`Fee = M * (ta * log10(1 - a * N) - tb * log10(1 - b * N))`

where
`M = 0.18 ; N=0.99`

### Fee Function for Redemption

Relative fee values are between 0% (exclusive) and ~31.24% (inclusive).

Functional form for absolute fee is as follows:

`Fee = scale * (tb * log10(b+shift) - ta * log10(a+shift)) + C*amount`

where
`scale=0.3 ; shift=0.1 ; C=scale*log10(1+shift)=scale*0.0413926851582251=0.0124178055474675`

## Fee Function Graphs

The following graphs illustrate the fee functions for deposit and redemption.

### Deposit Fee Function Graph

![Deposit Fee Function Graph](https://github.com/neutral-protocol/dynamic-fee-pools/assets/11928766/8247198c-a620-4533-aede-fa827a3cfc46)

In this graph, the X-axis represents the dominance of an asset, and the Y-axis represents the relative fee for deposit.

### Redemption Fee Function Graph

![Redemption Fee Function Graph](https://github.com/neutral-protocol/dynamic-fee-pools/assets/11928766/e308e855-b89e-4311-b182-28f81bc3ab94)

In this graph, the X-axis represents the dominance of an asset, and the Y-axis represents the relative fee for redemption.

These graphs help visualize how the fee changes based on the dominance of an asset in the pool. As the dominance of an asset increases, so does the fee for depositing more of that asset. Conversely, as the dominance of an asset decreases, so does the fee for redeeming that asset.

This fee structure is designed to maintain a balanced composition in the pool and discourage monopolization by any single asset.

### Conclusion

The FeeCalculator contract uses these mathematical models to calculate fees for deposit and redemption operations. By understanding these functions, users can make informed decisions about their transactions to optimize their costs.

Remember, the goal is to maintain a balanced pool composition and discourage monopolization by any single asset.




## How to Use

1. Deploy the contract on a Polygon network.
2. Call `feeSetup` function to set up the fee distribution among recipients.
3. Call `calculateDepositFees` function to calculate the deposit fees for a given amount.
4. Call `calculateRedemptionFee` function to calculate the redemption fees for a given amount.

## Requirements

- Solidity ^0.8.13
- OpenZeppelin Contracts
- PRBMath

## License

This project is unlicensed.
