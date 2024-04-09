// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FeeCalculator} from "../../src/FeeCalculator.sol";
import {FeeDistribution} from "../../src/interfaces/IFeeCalculator.sol";
import {SD59x18, sd, intoUint256 as sdIntoUint256} from "@prb/math/src/SD59x18.sol";
import {UD60x18, ud, intoUint256} from "@prb/math/src/UD60x18.sol";
import "../TestUtilities.sol";

abstract contract AbstractFeeCalculatorTestFuzzy is Test {
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

    function setProjectSupply(address token, uint256 supply) internal virtual;
    function calculateDepositFees(address pool, address token, uint256 amount) internal view virtual returns (FeeDistribution memory);
    function testCalculateRedemptionFeesFuzzy_RedemptionDividedIntoMultipleChunksFeesGreaterOrEqualToOneRedemption(
        uint8 numberOfRedemptions,
        uint128 _redemptionAmount,
        uint128 _current,
        uint128 _total
    ) public virtual;
    function testCalculateDepositFeesFuzzy_DepositDividedIntoMultipleChunksFeesGreaterOrEqualToOneDeposit(
        uint8 numberOfDeposits,
        uint256 depositAmount,
        uint256 current,
        uint256 total
    ) public virtual;

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
        setProjectSupply(address(mockToken), 1e9 * 1e18);

        vm.expectRevert("Fee must be greater than 0");
        calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
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
        setProjectSupply(address(mockToken), 100 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory gotRecipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(gotRecipients.length, recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            assertEq(gotRecipients[i], recipients[i]);
        }

        assertEq(fees.sumOf(), 11526003792614720250);

        assertApproxEqAbs(fees[0], 11526003792614720250 * uint256(firstShare) / 100, recipients.length - 1 + 1); //first fee might get the rest from division

        for (uint256 i = 1; i < recipients.length - 1; i++) {
            assertApproxEqAbs(fees[i], 11526003792614720250 * equalShare / 100, 1);
        }
        assertApproxEqAbs(fees[recipients.length - 1], 11526003792614720250 * (equalShare + leftShare) / 100, 1);
    }
}
