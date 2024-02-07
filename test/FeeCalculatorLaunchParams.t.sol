// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FeeCalculator} from "../src/FeeCalculator.sol";
import {FeeDistribution} from "../src/interfaces/IFeeCalculator.sol";
import "./TestUtilities.sol";

contract FeeCalculatorLaunchParamsTest is Test {
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

    function testCalculateDepositFeesNormalCase() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        mockPool.setProjectSupply(1, 500 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        // python based simulator value is 12.811562752294355
        assertEq(fees[0], 12811562752294360125);
    }

    function testCalculateDepositFeesNormalCase_TwoFeeRecipientsSplitEqually() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        mockPool.setProjectSupply(1, 500 * 1e18);

        address[] memory _recipients = new address[](2);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        uint256[] memory _feeShares = new uint256[](2);
        _feeShares[0] = 50;
        _feeShares[1] = 50;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(fees.sumOf(), 12811562752294360125);
        assertEq(fees[0], (uint256(12811562752294360125) / 2) + 1); //does not divide equally, first recipient gets rest
        assertEq(fees[1], uint256(12811562752294360125) / 2);
    }

    function testCalculateDepositFeesNormalCase_TwoFeeRecipientsSplit30To70() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        mockPool.setProjectSupply(1, 500 * 1e18);

        address[] memory _recipients = new address[](2);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        uint256[] memory _feeShares = new uint256[](2);
        _feeShares[0] = 30;
        _feeShares[1] = 70;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(fees.sumOf(), 12811562752294360125);
        assertEq(fees[0], uint256(12811562752294360125) * 30 / 100 + 1); //first recipient gets rest from division
        assertEq(fees[1], uint256(12811562752294360125) * 70 / 100);
    }

    function testCalculateDepositFeesComplicatedCase() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 932 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(53461 * 1e18);
        mockPool.setProjectSupply(1, 15462 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        // python based simulator value is 53.01387921583862
        assertEq(fees[0], 53013879215838797358);
    }

    function testCalculateDepositFees_DepositOfOneWei_ShouldThrowException() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setProjectSupply(1, 1e4 * 1e18);

        // Act
        vm.expectRevert("Fee must be greater than 0");
        feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
    }

    function testCalculateDepositFees_DepositOfHundredWei_ShouldThrowError() public {
        //Note! This is a bug, where a very small deposit to a very large pool
        //causes a == b because of precision limited by ratioDenominator in FeeCalculator

        // Arrange
        // Set up your test data
        uint256 depositAmount = 100;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setProjectSupply(1, 1e4 * 1e18);

        // Act
        vm.expectRevert("Fee must be greater than 0");
        feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
    }

    function testCalculateDepositFees_DepositOfHundredThousandsPartOfOne_NonzeroFee() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1e-5 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setProjectSupply(1, 1e4 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        //python based simulator value is 170744718950.4
        assertEq(fees[0], 170744712050);
    }

    function testCalculateDepositFees_DepositOfOne_NormalFee() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setProjectSupply(1, 1e4 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        // python based simulator value is 1.707527899250688e+16
        assertEq(fees[0], 17075278992520605);
    }

    function testCalculateDepositFees_DepositOfOne_NormalFee_FiveRecipientsEqualSplit() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1 * 1e18;
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
        address feeRecipient3 = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB;
        address feeRecipient4 = 0x583031D1113aD414F02576BD6afaBfb302140225;
        address feeRecipient5 = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setProjectSupply(1, 1e4 * 1e18);

        address[] memory _recipients = new address[](5);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        _recipients[2] = feeRecipient3;
        _recipients[3] = feeRecipient4;
        _recipients[4] = feeRecipient5;
        uint256[] memory _feeShares = new uint256[](5);
        _feeShares[0] = 20;
        _feeShares[1] = 20;
        _feeShares[2] = 20;
        _feeShares[3] = 20;
        _feeShares[4] = 20;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(recipients[2], feeRecipient3);
        assertEq(recipients[3], feeRecipient4);
        assertEq(recipients[4], feeRecipient5);
        // python based simulator value is 0.017075278992496123
        assertEq(fees.sumOf(), 17075278992520605);
        assertEq(fees[0], uint256(17075278992520605) * 20 / 100);
        assertEq(fees[1], uint256(17075278992520605) * 20 / 100);
        assertEq(fees[2], uint256(17075278992520605) * 20 / 100);
        assertEq(fees[3], uint256(17075278992520605) * 20 / 100);
        assertEq(fees[4], uint256(17075278992520605) * 20 / 100);
    }

    function testCalculateDepositFees_DepositOfOne_NormalFee_FiveRecipientsComplicatedSplit() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1 * 1e18;
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
        address feeRecipient3 = 0x4B0897b0513fdC7C541B6d9D7E929C4e5364D2dB;
        address feeRecipient4 = 0x583031D1113aD414F02576BD6afaBfb302140225;
        address feeRecipient5 = 0xdD870fA1b7C4700F2BD7f44238821C26f7392148;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setProjectSupply(1, 1e4 * 1e18);

        address[] memory _recipients = new address[](5);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        _recipients[2] = feeRecipient3;
        _recipients[3] = feeRecipient4;
        _recipients[4] = feeRecipient5;
        uint256[] memory _feeShares = new uint256[](5);
        _feeShares[0] = 15;
        _feeShares[1] = 30;
        _feeShares[2] = 50;
        _feeShares[3] = 3;
        _feeShares[4] = 2;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(recipients[2], feeRecipient3);
        assertEq(recipients[3], feeRecipient4);
        assertEq(recipients[4], feeRecipient5);
        // python based simulator value is 0.017075278992496123
        assertEq(fees.sumOf(), 17075278992520605);
        assertEq(fees[0], uint256(17075278992520605) * 15 / 100 + 2); //first recipient gets rest of fee
        assertEq(fees[1], uint256(17075278992520605) * 30 / 100);
        assertEq(fees[2], uint256(17075278992520605) * 50 / 100);
        assertEq(fees[3], uint256(17075278992520605) * 3 / 100);
        assertEq(fees[4], uint256(17075278992520605) * 2 / 100);
    }

    function testCalculateDepositFees_HugeTotalLargeCurrentSmallDeposit() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(100 * 1e6 * 1e18);
        mockPool.setProjectSupply(1, 1e6 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        // python based simulator value is 1635798849159168
        assertApproxEqRel(fees[0], 1635798849159168, 1e16);
    }

    function testCalculateDepositFees_ZeroDeposit_ExceptionShouldBeThrown() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 0;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        mockPool.setProjectSupply(1, 500 * 1e18);

        // Act
        vm.expectRevert("depositAmount must be > 0");
        feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
    }

    function testCalculateDepositFees_CurrentGreaterThanTotal_ExceptionShouldBeThrown() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        mockPool.setProjectSupply(1, 1500 * 1e18);

        // Act
        vm.expectRevert(
            "The total volume in the pool must be greater than or equal to the volume for an individual asset"
        );
        feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
    }

    function testCalculateDepositFees_EmptyPool_FeeCappedAt10Percent() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(0);
        mockPool.setProjectSupply(1, 0);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], depositAmount / 10);
    }

    function testCalculateDepositFees_AlmostEmptyPool_ExceptionShouldBeThrown() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1);
        mockPool.setProjectSupply(1, 0);

        // Act
        vm.expectRevert("Deposit outside range");
        feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
    }

    function testCalculateDepositFees_TotalEqualCurrent_FeeCappedAt10Percent() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000);
        mockPool.setProjectSupply(1, 1000);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], depositAmount / 10);
    }

    function testCalculateDepositFees_TotalAlmostEqualCurrent_ShouldThrowError() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000);
        mockPool.setProjectSupply(1, 999);

        // Act
        vm.expectRevert("Deposit outside range");
        feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
    }

    function testCalculateDepositFees_ZeroCurrent_NormalFees() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        mockPool.setProjectSupply(1, 0);

        // Act
        FeeDistribution memory feeDistribution =
            feeCalculator.calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        // python based simulator value is 7.858210418953233e+17
        assertEq(fees[0], 785821041895323300);
    }
}
