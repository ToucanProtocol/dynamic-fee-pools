# FeeCalculator

This is a Solidity contract that calculates deposit and redemption fees for a given pool. It implements `IDepositFeeCalculator` and `IRedemptionFeeCalculator` interfaces.

## Features

- Set up the fee distribution among recipients.
- Calculate the deposit fees for a given amount.
- Distribute the total fee among the recipients according to their shares.
- Calculate the redemption fees for a given amount.
- Get the balance of the TCO2 token in a given pool.
- Get the total supply of a given pool.
- Calculate the ratios for deposit fee calculation.
- Calculate the ratios for redemption fee calculation.
- Calculate the deposit fee for a given amount.
- Calculate the redemption fee for a given amount.

## How to Test
`forge test -vv --via-ir`

## Fee structure
Fee function is different in deposit and redemption but similar in behavior. Generally it is designed to punish monopolizing the pool with one asset harder the more monopolized it is. In other words doing a deposit of asset that already makes up e.g. 80% of the pool will result in higher fees, whereas doing a deposit with an asset that is not in the pool will result in lower fees. With redemption the situation is reversed, redeeming an asset that monopolizes the pool (thus improving pool composition) is cheap but redeeming an asset that consist of a very small percentage of the pool will be expensive.
Fee functions in both operations are based on dominance coefficients a and b, which designates the ratio of how dominant a particular asset is before (`a`) and after (`b`) operation.

`a = current_asset_volume / total_pool_volume`

`b = (current_asset_volume +/- deposit/redemption amount ) / (total_pool_volume +/- deposit/redemption amount)`


Another value that is used in functions is current `ta` (before operation) and future `tb` (after operation) amount of a particular asset in the pool

`ta = current_asset_volume`

`tb = current_asset_volume +/- deposit/redemption amount`


### Fee function for deposit
Relative fee values are between 0% (exclusive) and 36% (inclusive).
Functional form for absolute fee is as follows:

`Fee = M * (ta * log10(1 - a * N) - tb * log10(1 - b * N))`

where
`M = 0.18 ; N=0.99`

### Fee function for redemption
Relative fee values are between 0% (exclusive) and ~34.14% (inclusive).
Functional form for absolute fee is as follows:

`Fee = scale * (tb * log10(b+shift) - ta * log10(a+shift)) + C*amount`

where
`scale=0.3 ; shift=0.1 ; C=scale*log10(1+shift)=0.0413926851582251`


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
