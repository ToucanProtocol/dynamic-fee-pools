// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FeeCalculator} from "../src/FeeCalculator.sol";
import {FeeDistribution} from "../src/interfaces/IFeeCalculator.sol";
import {SD59x18, sd, intoUint256 as sdIntoUint256} from "@prb/math/src/SD59x18.sol";
import {UD60x18, ud, intoUint256} from "@prb/math/src/UD60x18.sol";
import "./TestUtilities.sol";

contract FeeCalculatorTestFuzzy is Test {
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
        mockPool.setProjectSupply(1, 1e9 * 1e18);

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
        mockPool.setProjectSupply(1, current);

        // Act
        try feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount) {}
        catch Error(string memory reason) {
            assertTrue(
                keccak256(bytes("Fee must be greater than 0")) == keccak256(bytes(reason))
                    || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason)),
                "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount'"
            );
        }
    }

    function testCalculateRedemptionFeesFuzzy_RedemptionDividedIntoOneChunkFeesGreaterOrEqualToOneRedemption(
        uint128 _redemptionAmount,
        uint128 _current,
        uint128 _total
    ) public {
        //just a sanity check
        testCalculateRedemptionFeesFuzzy_RedemptionDividedIntoMultipleChunksFeesGreaterOrEqualToOneRedemption(
            1, _redemptionAmount, _current, _total
        );
    }

    function testCalculateRedemptionFeesFuzzy_RedemptionDividedIntoMultipleChunksFeesGreaterOrEqualToOneRedemption(
        uint8 numberOfRedemptions,
        uint128 _redemptionAmount,
        uint128 _current,
        uint128 _total
    ) public {
        vm.assume(0 < numberOfRedemptions);
        vm.assume(_total >= _current);
        vm.assume(_redemptionAmount <= _current);
        vm.assume(_redemptionAmount < 1e20 * 1e18);
        vm.assume(_total < 1e20 * 1e18);
        vm.assume(_redemptionAmount > 1e-6 * 1e18);
        vm.assume(_current > 1e12);

        uint256 redemptionAmount = _redemptionAmount;
        uint256 current = _current;
        uint256 total = _total;

        SD59x18 dustAssetRedemptionRelativeFee = sd(0.3 * 1e18);

        // Arrange
        // Set up your test data

        // Set up mock pool
        mockPool.setTotalSupply(total);
        mockPool.setProjectSupply(1, current);
        uint256 oneTimeFee = 0;
        bool oneTimeRedemptionFailed = false;
        uint256 multipleTimesRedemptionFailedCount = 0;

        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Act
        try feeCalculator.calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts) returns (
            FeeDistribution memory feeDistribution
        ) {
            oneTimeFee = feeDistribution.shares.sumOf();
        } catch Error(string memory reason) {
            oneTimeRedemptionFailed = true;
            assertTrue(
                keccak256(bytes("Fee must be greater than 0")) == keccak256(bytes(reason))
                    || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason)),
                "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount'"
            );
        }

        /// @dev if we fail at the first try, we do not want to test the rest of the function
        vm.assume(oneTimeRedemptionFailed == false);
        /// @dev This prevents the case when the fee is so small that it is being calculated using dustAssetRedemptionRelativeFee
        /// @dev we don not want to test this case
        vm.assume(oneTimeFee != sdIntoUint256(sd(int256(redemptionAmount)) * dustAssetRedemptionRelativeFee));

        uint256 equalRedemption = redemptionAmount / numberOfRedemptions;
        uint256 restRedemption = redemptionAmount % numberOfRedemptions;
        uint256 feeFromDividedRedemptions = 0;

        for (uint256 i = 0; i < numberOfRedemptions; i++) {
            uint256 redemption = equalRedemption + (i == 0 ? restRedemption : 0);
            redemptionAmounts[0] = redemption;
            try feeCalculator.calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts) returns (
                FeeDistribution memory feeDistribution
            ) {
                feeFromDividedRedemptions += feeDistribution.shares.sumOf();
                total -= redemption;
                current -= redemption;
                mockPool.setTotalSupply(total);
                mockPool.setProjectSupply(1, current);
            } catch Error(string memory reason) {
                multipleTimesRedemptionFailedCount++;
                assertTrue(
                    keccak256(bytes("Fee must be greater than 0")) == keccak256(bytes(reason))
                        || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason)),
                    "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount'"
                );
            }
        }

        // @dev we allow for 0.1% error
        assertGe(1001 * feeFromDividedRedemptions / 1000, oneTimeFee);
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
        mockPool.setProjectSupply(1, current);

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
                    || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason)),
                "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount'"
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
                mockPool.setProjectSupply(1, current);
            } catch Error(string memory reason) {
                multipleTimesDepositFailedCount++;
                assertTrue(
                    keccak256(bytes("Fee must be greater than 0")) == keccak256(bytes(reason))
                        || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason)),
                    "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount'"
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

    function testFeeSetupFuzzy(address[] memory recipients, uint8 firstShare) public {
        vm.assume(recipients.length <= 100);
        vm.assume(recipients.length > 1); //at least two recipients
        vm.assume(firstShare <= 100);
        vm.assume(firstShare > 0);

        uint256[] memory feeShares = new uint256[](recipients.length);

        uint256 shareLeft = 100 - firstShare;
        feeShares[0] = firstShare;
        uint256 equalShare = shareLeft / (recipients.length - 1);
        uint256 leftShare = shareLeft % (recipients.length - 1);

        for (uint256 i = 1; i < recipients.length; i++) {
            feeShares[i] = equalShare;
        }
        feeShares[recipients.length - 1] += leftShare; //last one gets additional share
        feeCalculator.feeSetup(recipients, feeShares);

        uint256 depositAmount = 100 * 1e18;
        // Set up mock pool
        mockPool.setTotalSupply(200 * 1e18);
        mockPool.setProjectSupply(1, 100 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory gotRecipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(gotRecipients.length, recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            assertEq(gotRecipients[i], recipients[i]);
        }

        assertEq(fees.sumOf(), 16955006527425091575);

        assertApproxEqAbs(fees[0], 16955006527425091575 * uint256(firstShare) / 100, recipients.length - 1 + 1); //first fee might get the rest from division

        for (uint256 i = 1; i < recipients.length - 1; i++) {
            assertApproxEqAbs(fees[i], 16955006527425091575 * equalShare / 100, 1);
        }
        assertApproxEqAbs(fees[recipients.length - 1], 16955006527425091575 * (equalShare + leftShare) / 100, 1);
    }
}
