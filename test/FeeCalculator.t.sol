// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FeeCalculator} from "../src/FeeCalculator.sol";
import {UD60x18, ud, intoUint256} from "@prb/math/src/UD60x18.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockPool is IERC20 {
    uint256 private _totalSupply;

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function setTotalSupply(uint256 ts) public {
        _totalSupply = ts;
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transfer(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return 0;
    }
}

contract MockToken is IERC20 {
    mapping(address => uint256) public override balanceOf;

    function setTokenBalance(address pool, uint256 balance) public {
        balanceOf[pool] = balance;
    }

    function allowance(address, address) external pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transfer(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure override returns (bool) {
        return true;
    }

    function totalSupply() external view returns (uint256) {
        return 0;
    }
}

contract FeeCalculatorTest is Test {
    UD60x18 private zero = ud(0);
    UD60x18 private one = ud(1e18);
    UD60x18 private redemptionFeeScale = ud(0.3 * 1e18);
    UD60x18 private redemptionFeeShift = ud(0.1 * 1e18); //-log10(0+0.1)=1 -> 10^-1
    UD60x18 private redemptionFeeConstant = redemptionFeeScale * (one + redemptionFeeShift).log10(); //0.0413926851582251=log10(1+0.1)

    FeeCalculator public feeCalculator;
    MockPool public mockPool;
    MockToken public mockToken;
    address public feeRecipient = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;

    uint256 private depositFeeScale = 2;
    uint256 private redemptionFeeDivider = 3;

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

    function testFeeSetupEmpty() public {
        address[] memory recipients = new address[](0);
        uint256[] memory feeShares = new uint256[](0);
        vm.expectRevert("Total shares must equal 100");
        feeCalculator.feeSetup(recipients, feeShares);
    }

    function testCalculateDepositFeesNormalCase() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 500 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 9718378209069523938);
    }

    function testCalculateRedemptionFeesNormalCase() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 500 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemptionAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 2833521467902860250);
    }

    function testCalculateRedemptionFees_ZeroMonopolization_MaximumFees() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e6 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemptionAmount);

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

        // Set up mock pool
        mockPool.setTotalSupply(1e6 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e6 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemptionAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], redemptionAmount / 10);
    }

    function testCalculateRedemptionFees_AlmostFullMonopolization_ZeroFees() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e6 * 1e18 + 1);
        mockToken.setTokenBalance(address(mockPool), 1e6 * 1e18);

        // Act
        try feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemptionAmount) returns (
            address[] memory recipients, uint256[] memory fees
        ) {
            // Assert
            assertEq(recipients[0], feeRecipient);
            assertEq(fees[0], 0);
            fail("Exception should be thrown");
        } catch Error(string memory reason) {
            assertEq("Fee must be greater than 0", reason);
        }
    }

    function testCalculateRedemptionFees_CurrentSlightLessThanTotal_AmountSuperSmall_ShouldResultInException() public {
        //this test was producing negative redemption fees before rounding extremely small negative redemption fees to zero
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 186843141273221600445448244614; //1.868e29

        // Set up mock pool
        mockPool.setTotalSupply(11102230246251565404236316680908203126); //1.11e37
        mockToken.setTokenBalance(address(mockPool), 11102230246251565403820829061134812052); //1.11e37

        // Act
        try feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemptionAmount) returns (
            address[] memory recipients, uint256[] memory fees
        ) {
            // Assert
            assertEq(recipients[0], feeRecipient);
            assertEq(fees[0], 0);
            fail("Exception should be thrown");
        } catch Error(string memory reason) {
            assertEq("Fee must be greater than 0", reason);
        }
    }

    function testCalculateDepositFeesNormalCase_TwoFeeRecipientsSplitEqually() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;

        // Set up mock pool
        mockPool.setTotalSupply(1000 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 500 * 1e18);

        address[] memory _recipients = new address[](2);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        uint256[] memory _feeShares = new uint256[](2);
        _feeShares[0] = 50;
        _feeShares[1] = 50;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(sumOf(fees), 9718378209069523938);
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
        mockToken.setTokenBalance(address(mockPool), 500 * 1e18);

        address[] memory _recipients = new address[](2);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        uint256[] memory _feeShares = new uint256[](2);
        _feeShares[0] = 30;
        _feeShares[1] = 70;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(sumOf(fees), 9718378209069523938);
        assertEq(fees[0], uint256(9718378209069523938) * 30 / 100 + 1); //first recipient gets rest from division
        assertEq(fees[1], uint256(9718378209069523938) * 70 / 100);
    }

    function testCalculateDepositFeesComplicatedCase() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 932 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(53461 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 15462 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 46413457506542766270);
    }

    function testCalculateDepositFees_DepositOfOneWei_ShouldThrowException() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

        // Act
        try feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount) returns (
            address[] memory recipients, uint256[] memory fees
        ) {
            // Assert
            assertEq(recipients[0], feeRecipient);
            assertEq(fees[0], depositAmount);
            fail("Exception should be thrown");
        } catch Error(string memory reason) {
            assertEq("Fee must be greater than 0", reason);
        }
    }

    function testCalculateDepositFees_DepositOfHundredWei_ShouldThrowError() public {
        //Note! This is a bug, where a very small deposit to a very large pool
        //causes a == b because of precision limited by ratioDenominator in FeeCalculator

        // Arrange
        // Set up your test data
        uint256 depositAmount = 100;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

        // Act
        try feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount) returns (
            address[] memory recipients, uint256[] memory fees
        ) {
            // Assert
            assertEq(recipients[0], feeRecipient);
            assertEq(fees[0], depositAmount);
            fail("Exception should be thrown");
        } catch Error(string memory reason) {
            assertEq("Fee must be greater than 0", reason);
        }
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

        try feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount) returns (
            address[] memory recipients, uint256[] memory fees
        ) {
            // Assert
            assertEq(recipients[0], feeRecipient);
            assertEq(fees[0], depositAmount);
            fail("Exception should be thrown");
        } catch Error(string memory reason) {
            assertEq("Fee must be greater than 0", reason);
        }
    }

    function testCalculateDepositFees_DepositOfHundredThousandsPartOfOne_NonzeroFee() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1e-5 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

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
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

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
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

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
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(recipients[2], feeRecipient3);
        assertEq(recipients[3], feeRecipient4);
        assertEq(recipients[4], feeRecipient5);
        assertEq(sumOf(fees), 15880809772898785);
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
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

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
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(recipients[2], feeRecipient3);
        assertEq(recipients[3], feeRecipient4);
        assertEq(recipients[4], feeRecipient5);
        assertEq(sumOf(fees), 15880809772898785);
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
        mockToken.setTokenBalance(address(mockPool), 1e6 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

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
        mockToken.setTokenBalance(address(mockPool), 500 * 1e18);

        // Act
        try feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount) returns (
            address[] memory recipients, uint256[] memory fees
        ) {
            // Assert
            assertEq(recipients[0], feeRecipient);
            assertEq(fees[0], 0);
            fail("Exception should be thrown");
        } catch Error(string memory reason) {
            assertEq("depositAmount must be > 0", reason);
        }
    }

    function testCalculateDepositFees_EmptyPool_FeeCappedAt10Percent() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(0);
        mockToken.setTokenBalance(address(mockPool), 0);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

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
        mockToken.setTokenBalance(address(mockPool), 0);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 35999999999999999154);
    }

    function testCalculateRedemptionFees_TotalEqualCurrent_FeeCappedAt10Percent() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 100;

        // Set up mock pool
        mockPool.setTotalSupply(1000);
        mockToken.setTokenBalance(address(mockPool), 1000);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemptionAmount);

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
        mockToken.setTokenBalance(address(mockPool), 1000);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

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
        mockToken.setTokenBalance(address(mockPool), 999);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

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
        mockToken.setTokenBalance(address(mockPool), 0);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 737254938220315128);
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
        try feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount) returns (
            address[] memory recipients, uint256[] memory fees
        ) {
            // Assert
            assertEq(recipients[0], feeRecipient);
        } catch Error(string memory reason) {
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

        // Arrange
        // Set up your test data

        // Set up mock pool
        mockPool.setTotalSupply(total);
        mockToken.setTokenBalance(address(mockPool), current);
        uint256 oneTimeFee = 0;
        bool oneTimeRedemptionFailed = false;
        uint256 multipleTimesRedemptionFailedCount = 0;

        // Act
        try feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemptionAmount) returns (
            address[] memory recipients, uint256[] memory fees
        ) {
            oneTimeFee = fees[0];

            // Assert
            assertEq(recipients[0], feeRecipient);
        } catch Error(string memory reason) {
            oneTimeRedemptionFailed = true;
            assertTrue(
                keccak256(bytes("Fee must be greater than 0")) == keccak256(bytes(reason))
                    || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason)),
                "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount'"
            );
        }

        uint256 equalRedemption = redemptionAmount / numberOfRedemptions;
        uint256 restRedemption = redemptionAmount % numberOfRedemptions;
        uint256 feeFromDividedRedemptions = 0;

        for (uint256 i = 0; i < numberOfRedemptions; i++) {
            uint256 redemption = equalRedemption + (i == 0 ? restRedemption : 0);
            try feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemption) returns (
                address[] memory recipients, uint256[] memory fees
            ) {
                feeFromDividedRedemptions += fees[0];
                total -= redemption;
                current -= redemption;
                mockPool.setTotalSupply(total);
                mockToken.setTokenBalance(address(mockPool), current);
            } catch Error(string memory reason) {
                multipleTimesRedemptionFailedCount++;
                assertTrue(
                    keccak256(bytes("Fee must be greater than 0")) == keccak256(bytes(reason))
                        || keccak256(bytes("Fee must be lower or equal to deposit amount")) == keccak256(bytes(reason)),
                    "error should be 'Fee must be greater than 0' or 'Fee must be lower or equal to deposit amount'"
                );
            }
        }

        // Assert
        if (multipleTimesRedemptionFailedCount == 0 && !oneTimeRedemptionFailed) {
            uint256 maximumAllowedErrorPercentage = (numberOfRedemptions <= 1) ? 0 : 1;
            if (
                oneTimeFee + feeFromDividedRedemptions > 1e-8 * 1e18 // we skip assertion for extremely small fees (basically zero fees) because of numerical errors
            ) {
                assertGe((maximumAllowedErrorPercentage + 100) * feeFromDividedRedemptions / 100, oneTimeFee);
            } //we add 1% tolerance for numerical errors
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
        try feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount) returns (
            address[] memory recipients, uint256[] memory fees
        ) {
            oneTimeFee = fees[0];

            // Assert
            assertEq(recipients[0], feeRecipient);
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

            try feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), deposit) returns (
                address[] memory recipients, uint256[] memory fees
            ) {
                feeFromDividedDeposits += fees[0];
                total += deposit;
                current += deposit;
                mockPool.setTotalSupply(total);
                mockToken.setTokenBalance(address(mockPool), current);
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

    function sumOf(uint256[] memory numbers) public pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < numbers.length; i++) {
            sum += numbers[i];
        }
        return sum;
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
        mockToken.setTokenBalance(address(mockPool), 100 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) =
            feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        for (uint256 i = 0; i < recipients.length; i++) {
            assertEq(recipients[i], recipients[i]);
        }

        assertEq(sumOf(fees), 11526003792614720250);

        assertApproxEqAbs(fees[0], 11526003792614720250 * uint256(firstShare) / 100, recipients.length - 1 + 1); //first fee might get the rest from division

        for (uint256 i = 1; i < recipients.length - 1; i++) {
            assertApproxEqAbs(fees[i], 11526003792614720250 * equalShare / 100, 1);
        }
        assertApproxEqAbs(fees[recipients.length - 1], 11526003792614720250 * (equalShare + leftShare) / 100, 1);
    }
}
