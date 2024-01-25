// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FeeCalculator} from "../src/FeeCalculator.sol";
import {FeeDistribution} from "../src/interfaces/IFeeCalculator.sol";
import "./TestUtilities.sol";

contract FeeCalculatorLaunchParamsTestFuzzy is Test {
    using TestUtilities for uint256[];

    FeeCalculator public feeCalculator;
    MockPool public mockPool;
    MockToken public mockToken;
    address public feeRecipient = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;

    function setUp() public {
        feeCalculator = new FeeCalculator();
        mockPool = new MockPool();
        mockToken = new MockToken();
        address[] memory recipients = new address[](1);
        recipients[0] = feeRecipient;
        uint256[] memory feeShares = new uint256[](1);
        feeShares[0] = 100;
        feeCalculator.feeSetup(recipients, feeShares);
        // set up fee calculator launch params
        feeCalculator.setDepositFeeScale(0.15 * 1e18);
        feeCalculator.setDepositFeeRatioScale(1.25 * 1e18);
    }

    function testCalculateDepositFees_FuzzyExtremelySmallDepositsToLargePool_ShouldThrowError(uint256 depositAmount)
        public
    {
        vm.assume(depositAmount <= 1e-14 * 1e18);
        vm.assume(depositAmount >= 10);

        //Note! This is a bug, where a very small deposit to a very large pool
        //causes a == b because of precision limited by ratioDenominator in FeeCalculator

        // Arrange
        // Set up your test data

        // Set up mock pool
        mockPool.setTotalSupply(1e12 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e9 * 1e18);

        vm.expectRevert("Fee must be greater than 0");
        feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
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
        mockToken.setTokenBalance(address(mockPool), current);

        // Act
        try feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount) {}
        catch Error(string memory reason) {
            assertTrue(
                keccak256(bytes("Fee must be greater than 0")) == keccak256(bytes(reason))
                    || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason))
                    || keccak256(bytes("Deposit outside range")) == keccak256(bytes(reason)),
                "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount' or 'Deposit outside range'"
            );
        }
    }

    function testCalculateDepositFeesFuzzy_DepositDividedIntoOneChunkFeesGreaterOrEqualToOneDeposit(
        uint256 depositAmount,
        uint256 current,
        uint256 total
    ) public {
        //just a sanity check
        testCalculateDepositFeesFuzzy_DepositDividedIntoMultipleChunksFeesGreaterOrEqualToOneDeposit(
            1, depositAmount, current, total
        );
    }

    function testCalculateDepositFeesFuzzy_DepositDividedIntoMultipleChunksFeesGreaterOrEqualToOneDeposit(
        uint8 numberOfDeposits,
        uint256 depositAmount,
        uint256 current,
        uint256 total
    ) public {
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
        mockToken.setTokenBalance(address(mockPool), current);

        uint256 oneTimeFee = 0;

        // Act
        try feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount) returns (
            FeeDistribution memory feeDistribution
        ) {
            oneTimeFee = feeDistribution.shares.sumOf();
        } catch Error(string memory reason) {
            oneTimeDepositFailed = true;
            assertTrue(
                keccak256(bytes("Fee must be greater than 0")) == keccak256(bytes(reason))
                    || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason))
                    || keccak256(bytes("Deposit outside range")) == keccak256(bytes(reason)),
                "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount' or 'Deposit outside range'"
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
                mockToken.setTokenBalance(address(mockPool), current);
            } catch Error(string memory reason) {
                multipleTimesDepositFailedCount++;
                assertTrue(
                    keccak256(bytes("Fee must be greater than 0")) == keccak256(bytes(reason))
                        || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason))
                        || keccak256(bytes("Deposit outside range")) == keccak256(bytes(reason)),
                    "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount' or 'Deposit outside range'"
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
