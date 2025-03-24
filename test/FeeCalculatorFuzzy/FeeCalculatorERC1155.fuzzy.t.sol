// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import "./AbstractFeeCalculator.fuzzy.t.sol";

contract FeeCalculatorERC1155TestFuzzy is AbstractFeeCalculatorTestFuzzy {
    using TestUtilities for uint256[];

    function setProjectSupply(address token, uint256 supply) internal override {
        mockPool.setERC1155Supply(address(token), 1, supply);
    }

    function calculateDepositFees(address pool, address token, uint256 amount)
        internal
        view
        override
        returns (FeeDistribution memory)
    {
        return feeCalculator.calculateDepositFees(address(pool), address(token), 1, amount);
    }

    function testCalculateDepositFeesFuzzy(uint256 depositAmount, uint256 current, uint256 total) public {
        //vm.assume(depositAmount > 0);
        //vm.assume(total > 0);
        //vm.assume(current > 0);
        vm.assume(total >= current);
        vm.assume(depositAmount < 1e20 * 1e18);
        vm.assume(depositAmount > 0);
        vm.assume(total < 1e20 * 1e18);

        // Arrange
        // Set up your test data

        // Set up mock pool
        mockPool.setTotalSupply(total);
        mockPool.setTCO2Supply(address(mockToken), current);

        // Act
        try feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), 1, depositAmount) {}
        catch Error(string memory reason) {
            assertTrue(
                keccak256(bytes("Fee must be lower or equal to requested amount")) == keccak256(bytes(reason)),
                "error should be 'Fee must be lower or equal to requested amount'"
            );
        }
    }

    struct FuzzCalculationArgs {
        uint8 numberOfRedemptions;
        uint256 redemptionAmount;
        uint256 current;
        uint256 total;
        SD59x18 dustAssetRedemptionRelativeFee;
        uint256 oneTimeFee;
        bool oneTimeRedemptionFailed;
        uint256 multipleTimesRedemptionFailedCount;
        address[] tco2s;
        uint256[] tokenIds;
        uint256[] redemptionAmounts;
        uint256 equalRedemption;
        uint256 restRedemption;
        uint256 feeFromDividedRedemptions;
    }

    function testCalculateRedemptionFeesFuzzy_RedemptionDividedIntoMultipleChunksFeesGreaterOrEqualToOneRedemption(
        uint8 numberOfRedemptions,
        uint128 _redemptionAmount,
        uint128 _current,
        uint128 _total
    ) public override {
        vm.assume(0 < numberOfRedemptions);
        vm.assume(_total >= _current);
        vm.assume(_redemptionAmount <= _current);
        vm.assume(_redemptionAmount < 1e20 * 1e18);
        vm.assume(_total < 1e20 * 1e18);
        vm.assume(_redemptionAmount > 1e-6 * 1e18);
        vm.assume(_current > 1e12);

        // Arrange
        // Set up your test data

        FuzzCalculationArgs memory args = FuzzCalculationArgs({
            numberOfRedemptions: numberOfRedemptions,
            redemptionAmount: uint128(_redemptionAmount),
            current: uint128(_current),
            total: uint128(_total),
            dustAssetRedemptionRelativeFee: sd(0.3 * 1e18),
            oneTimeFee: 0,
            oneTimeRedemptionFailed: false,
            multipleTimesRedemptionFailedCount: 0,
            tco2s: new address[](1),
            tokenIds: new uint256[](1),
            redemptionAmounts: new uint256[](1),
            equalRedemption: 0,
            restRedemption: 0,
            feeFromDividedRedemptions: 0
        });

        // Set up mock pool
        mockPool.setTotalSupply(args.total);
        setProjectSupply(address(mockToken), args.current);

        args.tco2s[0] = address(mockToken);
        args.tokenIds[0] = 1;
        args.redemptionAmounts[0] = args.redemptionAmount;

        // Act
        try feeCalculator.calculateRedemptionFees(address(mockPool), args.tco2s, args.tokenIds, args.redemptionAmounts)
        returns (FeeDistribution memory feeDistribution) {
            args.oneTimeFee = feeDistribution.shares.sumOf();
        } catch Error(string memory reason) {
            args.oneTimeRedemptionFailed = true;
            assertTrue(
                keccak256(bytes("Fee must be lower or equal to requested amount")) == keccak256(bytes(reason)),
                "error should be 'Fee must be lower or equal to requested amount'"
            );
        }

        /// @dev if we fail at the first try, we do not want to test the rest of the function
        vm.assume(args.oneTimeRedemptionFailed == false);
        /// @dev This prevents the case when the fee is so small that it is being calculated using dustAssetRedemptionRelativeFee
        /// @dev we don not want to test this case
        vm.assume(
            args.oneTimeFee != sdIntoUint256(sd(int256(args.redemptionAmount)) * args.dustAssetRedemptionRelativeFee)
        );

        args.equalRedemption = args.redemptionAmount / args.numberOfRedemptions;
        args.restRedemption = args.redemptionAmount % args.numberOfRedemptions;

        for (uint256 i = 0; i < args.numberOfRedemptions; i++) {
            uint256 redemption = args.equalRedemption + (i == 0 ? args.restRedemption : 0);
            args.redemptionAmounts[0] = redemption;
            try feeCalculator.calculateRedemptionFees(
                address(mockPool), args.tco2s, args.tokenIds, args.redemptionAmounts
            ) returns (FeeDistribution memory feeDistribution) {
                args.feeFromDividedRedemptions += feeDistribution.shares.sumOf();
                args.total -= redemption;
                args.current -= redemption;
                mockPool.setTotalSupply(args.total);
                setProjectSupply(address(mockToken), args.current);
            } catch Error(string memory reason) {
                args.multipleTimesRedemptionFailedCount++;
                assertTrue(
                    keccak256(bytes("Fee must be lower or equal to requested amount")) == keccak256(bytes(reason)),
                    "error should be 'Fee must be lower or equal to requested amount'"
                );
            }
        }

        // @dev we allow for 0.1% error
        assertGe(1001 * args.feeFromDividedRedemptions / 1000, args.oneTimeFee);
    }

    function testCalculateDepositFeesFuzzy_DepositDividedIntoMultipleChunksFeesGreaterOrEqualToOneDeposit(
        uint8 numberOfDeposits,
        uint256 depositAmount,
        uint256 current,
        uint256 total
    ) public override {
        vm.assume(0 < numberOfDeposits);
        vm.assume(total >= current);

        vm.assume(depositAmount < 1e20 * 1e18);
        vm.assume(total < 1e20 * 1e18);

        vm.assume(depositAmount > 1e-6 * 1e18);

        // Arrange
        // Set up your test data
        bool oneTimeDepositFailed = false;
        uint256 multipleTimesDepositFailedCount = 0;
        // Set up mock pool
        mockPool.setTotalSupply(total);
        setProjectSupply(address(mockToken), current);

        uint256 oneTimeFee = 0;

        // Act
        try feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), 1, depositAmount) returns (
            FeeDistribution memory feeDistribution
        ) {
            oneTimeFee = feeDistribution.shares.sumOf();
        } catch Error(string memory reason) {
            oneTimeDepositFailed = true;
            assertTrue(
                keccak256(bytes("Fee must be lower or equal to requested amount")) == keccak256(bytes(reason)),
                "error should be 'Fee must be lower or equal to requested amount'"
            );
        }

        uint256 equalDeposit = depositAmount / numberOfDeposits;
        uint256 restDeposit = depositAmount % numberOfDeposits;
        uint256 feeFromDividedDeposits = 0;

        for (uint256 i = 0; i < numberOfDeposits; i++) {
            uint256 deposit = equalDeposit + (i == 0 ? restDeposit : 0);

            try feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), 1, deposit) returns (
                FeeDistribution memory feeDistribution
            ) {
                feeFromDividedDeposits += feeDistribution.shares.sumOf();
                total += deposit;
                current += deposit;
                mockPool.setTotalSupply(total);
                setProjectSupply(address(mockToken), current);
            } catch Error(string memory reason) {
                multipleTimesDepositFailedCount++;
                assertTrue(
                    keccak256(bytes("Fee must be lower or equal to requested amount")) == keccak256(bytes(reason)),
                    "error should be 'Fee must be lower or equal to requested amount'"
                );
            }
        }

        // Assert
        if (multipleTimesDepositFailedCount == 0 && !oneTimeDepositFailed) {
            uint256 maximumAllowedErrorPercentage = (numberOfDeposits <= 1) ? 0 : 2;
            if (
                oneTimeFee + feeFromDividedDeposits > 1e-8 * 1e18 // we skip assertion for extremely small fees (basically zero fees) because of numerical errors
            ) {
                assertGe((maximumAllowedErrorPercentage + 100) * feeFromDividedDeposits / 100, oneTimeFee);
            } //we add 1% tolerance for numerical errors
        }
    }
}
