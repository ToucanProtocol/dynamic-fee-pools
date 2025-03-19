// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FeeCalculator} from "../../src/FeeCalculator.sol";
import {FeeDistribution} from "../../src/interfaces/IFeeCalculator.sol";
import "../TestUtilities.sol";
import "forge-std/console.sol";

abstract contract AbstractFeeCalculatorLaunchParamsTestFuzzy is Test {
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

    function setProjectSupply(address token, uint256 supply) internal virtual;
    function calculateDepositFees(address pool, address token, uint256 amount)
        internal
        view
        virtual
        returns (FeeDistribution memory);
    function testCalculateDepositFeesFuzzy(uint256 depositAmount, uint256 current, uint256 total) public virtual;
    function testCalculateDepositFeesFuzzy_DepositDividedIntoMultipleChunksFeesGreaterOrEqualToOneDeposit(
        uint8 numberOfDeposits,
        uint256 depositAmount,
        uint256 current,
        uint256 total
    ) public virtual;

    function testCalculateDepositFees_FuzzyExtremelySmallDepositsToLargePool_ShouldNotThrowError(uint256 depositAmount)
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
        setProjectSupply(address(mockToken), 1e9 * 1e18);

        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        assertEq(feeDistribution.recipients.length, 0);
        assertEq(feeDistribution.shares.length, 0);
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
}
