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
