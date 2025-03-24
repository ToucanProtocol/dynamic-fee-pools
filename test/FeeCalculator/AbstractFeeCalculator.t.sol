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

abstract contract AbstractFeeCalculatorTest is Test {
    using TestUtilities for uint256[];

    UD60x18 private one = ud(1e18);
    UD60x18 private redemptionFeeScale = ud(0.3 * 1e18);
    UD60x18 private redemptionFeeShift = ud(0.1 * 1e18); //-log10(0+0.1)=1 -> 10^-1
    UD60x18 private redemptionFeeConstant = redemptionFeeScale * (one + redemptionFeeShift).log10(); //0.0413926851582251=log10(1+0.1)

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
    function calculateDepositFees(address pool, address token, uint256 amount)
        internal
        view
        virtual
        returns (FeeDistribution memory);
    function calculateRedemptionFees(address pool, address[] memory tokens, uint256[] memory amounts)
        internal
        view
        virtual
        returns (FeeDistribution memory);

    function testFeeSetupEmpty() public {
        address[] memory recipients = new address[](0);
        uint256[] memory feeShares = new uint256[](0);
        vm.expectRevert("Total shares must equal 100");
        feeCalculator.feeSetup(recipients, feeShares);
    }

    function testGetFeeSetup() public {
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;

        address[] memory recipients = new address[](2);
        recipients[0] = feeRecipient1;
        recipients[1] = feeRecipient2;
        uint256[] memory feeShares = new uint256[](2);
        feeShares[0] = 30;
        feeShares[1] = 70;

        feeCalculator.feeSetup(recipients, feeShares);

        (address[] memory _recipients, uint256[] memory _feeShares) = feeCalculator.getFeeSetup();
        assertEq(_recipients[0], feeRecipient1);
        assertEq(_recipients[1], feeRecipient2);
        assertEq(_feeShares[0], 30);
        assertEq(_feeShares[1], 70);
    }

    function testCalculateDepositFeesNormalCase() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(feeDistribution.recipients.length, feeDistribution.shares.length, "array length mismatch");
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 9718378209069523938);
    }

    function testCalculateRedemptionFeesNormalCase() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 100 * 1e18;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(feeDistribution.recipients.length, feeDistribution.shares.length, "array length mismatch");
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 2833521467902860250);
    }

    function testCalculateRedemptionFees_ZeroMonopolization_MaximumFees() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 1 * 1e18;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pools
        mockPool.setTotalSupply(1e6 * 1e18);
        setProjectSupply(address(mockToken), 1 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertApproxEqRel(
            fees[0], intoUint256((redemptionFeeScale + redemptionFeeConstant) * (ud(redemptionAmount))), 1e15
        ); //we allow 0.1% discrepancy
    }

    function testCalculateRedemptionFees_FullMonopolization_FeesCappedAt10Percent() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 1 * 1e18;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        mockPool.setTotalSupply(1e6 * 1e18);
        setProjectSupply(address(mockToken), 1e6 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], redemptionAmount / 10);
    }

    function testCalculateDepositFeesNormalCase_TwoFeeRecipientsSplitEqually() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);

        address[] memory _recipients = new address[](2);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        uint256[] memory _feeShares = new uint256[](2);
        _feeShares[0] = 50;
        _feeShares[1] = 50;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(fees.sumOf(), 9718378209069523938);
        assertEq(fees[0], 9718378209069523938 / 2);
        assertEq(fees[1], 9718378209069523938 / 2);
    }

    function testCalculateDepositFeesNormalCase_TwoFeeRecipientsSplit30To70() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);

        address[] memory _recipients = new address[](2);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        uint256[] memory _feeShares = new uint256[](2);
        _feeShares[0] = 30;
        _feeShares[1] = 70;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(fees.sumOf(), 9718378209069523938);
        assertEq(fees[0], uint256(9718378209069523938) * 30 / 100 + 1); //first recipient gets rest from division
        assertEq(fees[1], uint256(9718378209069523938) * 70 / 100);
    }

    function testCalculateDepositFeesComplicatedCase() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 932 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(53461 * 1e18);
        setProjectSupply(address(mockToken), 15462 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 46413457506542766270);
    }

    function testCalculateDepositFees_DepositOfOneWei_ShouldNotThrowException() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        setProjectSupply(address(mockToken), 1e4 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        assertEq(feeDistribution.recipients.length, 0);
        assertEq(feeDistribution.shares.length, 0);
    }

    function testCalculateDepositFees_DepositOfHundredWei_ShouldNotThrowError() public {
        //Note! This is a bug, where a very small deposit to a very large pool
        //causes a == b because of precision limited by ratioDenominator in FeeCalculator

        // Arrange
        // Set up your test data
        uint256 depositAmount = 100;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        setProjectSupply(address(mockToken), 1e4 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        assertEq(feeDistribution.recipients.length, 0);
        assertEq(feeDistribution.shares.length, 0);
    }

    function testCalculateDepositFees_DepositOfHundredThousandsPartOfOne_NonzeroFee() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1e-5 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        setProjectSupply(address(mockToken), 1e4 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 158800759314);
    }

    function testCalculateDepositFees_DepositOfOne_NormalFee() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        setProjectSupply(address(mockToken), 1e4 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 15880809772898785);
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
        setProjectSupply(address(mockToken), 1e4 * 1e18);

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
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(recipients[2], feeRecipient3);
        assertEq(recipients[3], feeRecipient4);
        assertEq(recipients[4], feeRecipient5);
        assertEq(fees.sumOf(), 15880809772898785);
        assertEq(fees[0], uint256(15880809772898785) * 20 / 100);
        assertEq(fees[1], uint256(15880809772898785) * 20 / 100);
        assertEq(fees[2], uint256(15880809772898785) * 20 / 100);
        assertEq(fees[3], uint256(15880809772898785) * 20 / 100);
        assertEq(fees[4], uint256(15880809772898785) * 20 / 100);
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
        setProjectSupply(address(mockToken), 1e4 * 1e18);

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
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(recipients[2], feeRecipient3);
        assertEq(recipients[3], feeRecipient4);
        assertEq(recipients[4], feeRecipient5);
        assertEq(fees.sumOf(), 15880809772898785);
        assertEq(fees[0], uint256(15880809772898785) * 15 / 100 + 3); //first recipient gets rest of fee
        assertEq(fees[1], uint256(15880809772898785) * 30 / 100);
        assertEq(fees[2], uint256(15880809772898785) * 50 / 100);
        assertEq(fees[3], uint256(15880809772898785) * 3 / 100);
        assertEq(fees[4], uint256(15880809772898785) * 2 / 100);
    }

    function testCalculateDepositFees_HugeTotalLargeCurrentSmallDeposit() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(100 * 1e6 * 1e18);
        setProjectSupply(address(mockToken), 1e6 * 1e18);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 1551604479562604);
    }

    function testCalculateDepositFees_ZeroDeposit_ExceptionShouldBeThrown() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 0;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);

        // Act
        vm.expectRevert("requested amount must be > 0");
        calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
    }

    function testCalculateDepositFees_CurrentGreaterThanTotal_ExceptionShouldBeThrown() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 1500 * 1e18);

        // Act
        vm.expectRevert(
            "The total volume in the pool must be greater than or equal to the volume for an individual asset"
        );
        calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
    }

    function testCalculateRedemptionFees_CurrentGreaterThanTotal_ExceptionShouldBeThrown() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 1;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 1500 * 1e18);

        // Act & Assert
        vm.expectRevert(
            "The total volume in the pool must be greater than or equal to the volume for an individual asset"
        );
        calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
    }

    function testCalculateRedemptionFees_AmountGreaterThanCurrent_ExceptionShouldBeThrown() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 600 * 1e18;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);

        // Act
        vm.expectRevert("The amount to be redeemed cannot exceed the current balance of the pool");
        calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
    }

    function testCalculateRedemptionFees_ZeroRedemption_ExceptionShouldBeThrown() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 0;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);

        // Act & Assert
        vm.expectRevert("requested amount must be > 0");
        calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
    }

    function testCalculateDepositFees_EmptyPool_FeeCappedAt10Percent() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(0);
        setProjectSupply(address(mockToken), 0);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], depositAmount / 10);
    }

    function testCalculateDepositFees_AlmostEmptyPool_FeeAlmostCappedAt36Percent() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1);
        setProjectSupply(address(mockToken), 0);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 35999999999999999154);
    }

    function testCalculateRedemptionFees_ZeroDeposit_ExceptionShouldBeThrown() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 0;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);

        // Act
        vm.expectRevert("requested amount must be > 0");
        calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
    }

    function testCalculateRedemptionFees_TotalEqualCurrent_FeeCappedAt10Percent() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 100;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        mockPool.setTotalSupply(1000);
        setProjectSupply(address(mockToken), 1000);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], redemptionAmount / 10);
    }

    function testCalculateDepositFees_TotalEqualCurrent_FeeCappedAt10Percent() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000);
        setProjectSupply(address(mockToken), 1000);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], depositAmount / 10);
    }

    function testCalculateDepositFees_TotalAlmostEqualCurrent_FeeAlmostCappedAt36Percent() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000);
        setProjectSupply(address(mockToken), 999);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 35999999999999999161);
    }

    function testCalculateDepositFees_ZeroCurrent_NormalFees() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 0);

        // Act
        FeeDistribution memory feeDistribution =
            calculateDepositFees(address(mockPool), address(mockToken), depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 737254938220315128);
    }

    function testCalculateRedemptionFees_HugeTotalLargeCurrentSmallDeposit_FeeCappedAt30Percent() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 10000 * 1e18;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        uint256 supply = 100000 * 1e18;
        mockPool.setTotalSupply(100000 * 1e18);
        setProjectSupply(address(mockToken), supply - 1);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], redemptionAmount * 30 / 100);
    }

    function testCalculateRedemptionFees_NegativeFeeValue_FeeCappedAt30Percent() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 2323662174650;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        mockPool.setTotalSupply(56636794628913227180683983236);
        setProjectSupply(address(mockToken), 55661911070827884041095553095);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], redemptionAmount * 30 / 100);
    }

    function testFeeSetup_RecipientsEmpty_ShouldThrowError() public {
        // Arrange
        // Set up your test data
        address[] memory _recipients = new address[](0);
        uint256[] memory _feeShares = new uint256[](0);

        // Act & Assert
        vm.expectRevert("Total shares must equal 100");
        feeCalculator.feeSetup(_recipients, _feeShares);
    }

    function testFeeSetup_RecipientsAndSharesDifferentLength_ShouldThrowError() public {
        // Arrange
        // Set up your test data
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
        address[] memory _recipients = new address[](2);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        uint256[] memory _feeShares = new uint256[](3);
        _feeShares[0] = 20;
        _feeShares[1] = 20;
        _feeShares[2] = 60;

        // Act & Assert
        vm.expectRevert("Recipients and shares arrays must have the same length");
        feeCalculator.feeSetup(_recipients, _feeShares);
    }

    function testFeeSetup_RecipientsAndSharesSameLengthButSharesSumUpTo101_ShouldThrowError() public {
        // Arrange
        // Set up your test data
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;
        address feeRecipient3 = 0xb1bB642E2CD1E3254d3395f02483e3DA7baF2d83;
        address[] memory _recipients = new address[](3);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        _recipients[2] = feeRecipient3;
        uint256[] memory _feeShares = new uint256[](3);
        _feeShares[0] = 21;
        _feeShares[1] = 20;
        _feeShares[2] = 60;

        // Act & Assert
        vm.expectRevert("Total shares must equal 100");
        feeCalculator.feeSetup(_recipients, _feeShares);
    }

    function testSetDepositFeeScaleReverts() public {
        int256 invalid = (1.1 * 1e18);
        vm.expectRevert("Deposit fee scale must be between 0 and 1");
        feeCalculator.setDepositFeeScale(invalid);
    }

    function testSetSingleAssetDepositRelativeFeeReverts() public {
        int256 invalid = (1.3 * 1e18);
        vm.expectRevert("Single asset deposit relative fee must be between 0 and 1");
        feeCalculator.setSingleAssetDepositRelativeFee(invalid);
    }

    function testSetRedemptionFeeScaleReverts() public {
        int256 invalid = (1.4 * 1e18);
        vm.expectRevert("Redemption fee scale must be between 0 and 1");
        feeCalculator.setRedemptionFeeScale(invalid);
    }

    function testSetRedemptionFeeShiftReverts() public {
        int256 invalid = (1.5 * 1e18);
        vm.expectRevert("Redemption fee shift must be between 0 and 1");
        feeCalculator.setRedemptionFeeShift(invalid);
    }

    function testSetSingleAssetRedemptionRelativeFeeReverts() public {
        int256 invalid = (1.7 * 1e18);
        vm.expectRevert("Single asset redemption relative fee must be between 0 and 1");
        feeCalculator.setSingleAssetRedemptionRelativeFee(invalid);
    }

    function testSetDustAssetRedemptionRelativeFeeReverts() public {
        int256 invalid = (1.8 * 1e18);
        vm.expectRevert("Dust asset redemption relative fee must be between 0 and 1");
        feeCalculator.setDustAssetRedemptionRelativeFee(invalid);
    }

    function testSetDepositFeeScaleNegativeReverts() public {
        int256 invalid = (-0.1 * 1e18);
        vm.expectRevert("Deposit fee scale must be between 0 and 1");
        feeCalculator.setDepositFeeScale(invalid);
    }

    function testSetDepositFeeRatioScaleNegativeReverts() public {
        int256 invalid = (-0.2 * 1e18);
        vm.expectRevert("Deposit fee ratio scale must be above 0");
        feeCalculator.setDepositFeeRatioScale(invalid);
    }

    function testSetSingleAssetDepositRelativeFeeNegativeReverts() public {
        int256 invalid = (-0.3 * 1e18);
        vm.expectRevert("Single asset deposit relative fee must be between 0 and 1");
        feeCalculator.setSingleAssetDepositRelativeFee(invalid);
    }

    function testSetRedemptionFeeScaleNegativeReverts() public {
        int256 invalid = (-0.4 * 1e18);
        vm.expectRevert("Redemption fee scale must be between 0 and 1");
        feeCalculator.setRedemptionFeeScale(invalid);
    }

    function testSetRedemptionFeeShiftNegativeReverts() public {
        int256 invalid = (-0.5 * 1e18);
        vm.expectRevert("Redemption fee shift must be between 0 and 1");
        feeCalculator.setRedemptionFeeShift(invalid);
    }

    function testSetSingleAssetRedemptionRelativeFeeNegativeReverts() public {
        int256 invalid = (-0.7 * 1e18);
        vm.expectRevert("Single asset redemption relative fee must be between 0 and 1");
        feeCalculator.setSingleAssetRedemptionRelativeFee(invalid);
    }

    function testSetDustAssetRedemptionRelativeFeeNegativeReverts() public {
        int256 invalid = (-0.8 * 1e18);
        vm.expectRevert("Dust asset redemption relative fee must be between 0 and 1");
        feeCalculator.setDustAssetRedemptionRelativeFee(invalid);
    }

    function testSetDepositFeeScale() public {
        // Arrange
        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);
        feeCalculator.setDepositFeeScale(0.09 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateDepositFees(address(mockPool), address(mockToken), 100 * 1e18);
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(fees[0], 9718378209069523938 / 2);
    }

    function testSetDepositFeeRatioScale() public {
        // Arrange
        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);
        feeCalculator.setDepositFeeRatioScale(0.2 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateDepositFees(address(mockPool), address(mockToken), 100 * 1e18);
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(fees[0], 1299819671838098442);
    }

    function testSetSingleAssetDepositRelativeFee() public {
        // Arrange
        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 1000 * 1e18);
        feeCalculator.setSingleAssetDepositRelativeFee(0.67 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateDepositFees(address(mockPool), address(mockToken), 100 * 1e18);
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(fees[0], 67 * 1e18);
    }

    function testSetRedemptionFeeScale() public {
        // Arrange
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = 100e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);
        feeCalculator.setRedemptionFeeScale(0.4 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(fees[0], 3778028623870480400);
    }

    function testSetRedemptionFeeShift() public {
        // Arrange
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = 100e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 500 * 1e18);
        feeCalculator.setRedemptionFeeShift(0.5 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(fees[0], 2303907724666580660);
    }

    function testSetSingleAssetRedemptionRelativeFee() public {
        // Arrange
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        setProjectSupply(address(mockToken), 1000 * 1e18);
        feeCalculator.setSingleAssetRedemptionRelativeFee(0.83 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        uint256[] memory fees = feeDistribution.shares;

        assertEq(fees[0], 83 * 1e18);
    }

    function testSetDustAssetRedemptionRelativeFee() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 2323662174650;
        address[] memory tco2s = new address[](1);
        tco2s[0] = address(mockToken);
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Set up mock pool
        mockPool.setTotalSupply(56636794628913227180683983236);
        setProjectSupply(address(mockToken), 55661911070827884041095553095);
        feeCalculator.setDustAssetRedemptionRelativeFee(0.91 * 1e18);

        // Act
        FeeDistribution memory feeDistribution = calculateRedemptionFees(address(mockPool), tco2s, redemptionAmounts);
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(fees[0], redemptionAmount * 91 / 100);
    }
}
