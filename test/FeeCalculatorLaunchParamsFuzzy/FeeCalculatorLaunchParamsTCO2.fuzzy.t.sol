// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import "./AbstractFeeCalculatorLaunchParams.fuzzy.t.sol";

contract FeeCalculatorLaunchParamsTCO2TestFuzzy is AbstractFeeCalculatorLaunchParamsTestFuzzy {
    using TestUtilities for uint256[];

    function setProjectSupply(address token, uint256 supply) internal override {
        mockPool.setTCO2Supply(address(token), supply);
    }

    function calculateDepositFees(address pool, address token, uint256 amount)
        internal
        view
        override
        returns (FeeDistribution memory)
    {
        return feeCalculator.calculateDepositFees(address(pool), address(token), amount);
    }

    function testCalculateDepositFeesFuzzy(uint256 depositAmount, uint256 current, uint256 total) public override {
        vm.assume(total >= current);
        vm.assume(depositAmount < 1e20 * 1e18);
        vm.assume(depositAmount > 0);
        vm.assume(total < 1e20 * 1e18);

        // Arrange
        // Set up your test data

        // Set up mock pool
        mockPool.setTotalSupply(total);
        setProjectSupply(address(mockToken), current);

        // Act
        try feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount) {}
        catch Error(string memory reason) {
            assertTrue(
                keccak256(bytes("Fee must be lower or equal to requested amount")) == keccak256(bytes(reason))
                    || keccak256(bytes("Deposit outside range")) == keccak256(bytes(reason)),
                "error should be 'Fee must be lower or equal to requested amount' or 'Deposit outside range'"
            );
        }
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
        try feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount) returns (
            FeeDistribution memory feeDistribution
        ) {
            oneTimeFee = feeDistribution.shares.sumOf();
        } catch Error(string memory reason) {
            oneTimeDepositFailed = true;
            assertTrue(
                keccak256(bytes("Fee must be lower or equal to requested amount")) == keccak256(bytes(reason))
                    || keccak256(bytes("Deposit outside range")) == keccak256(bytes(reason)),
                "error should be 'Fee must be lower or equal to requested amount' or 'Deposit outside range'"
            );
        }

        uint256 equalDeposit = depositAmount / numberOfDeposits;
        uint256 restDeposit = depositAmount % numberOfDeposits;
        uint256 feeFromDividedDeposits = 0;

        for (uint256 i = 0; i < numberOfDeposits; i++) {
            uint256 deposit = equalDeposit + (i == 0 ? restDeposit : 0);

            try feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), deposit) returns (
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
                    keccak256(bytes("Fee must be lower or equal to requested amount")) == keccak256(bytes(reason))
                        || keccak256(bytes("Deposit outside range")) == keccak256(bytes(reason)),
                    "error should be 'Fee must be lower or equal to requested amount' or 'Deposit outside range'"
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
