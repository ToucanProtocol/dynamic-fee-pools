// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FeeCalculator} from "../../src/FeeCalculator.sol";
import {FeeDistribution} from "../../src/interfaces/IFeeCalculator.sol";
import {FlatFeeCalculator} from "../../src/FlatFeeCalculator.sol";

contract FlatFeeCalculatorTestFuzzy is Test {
    FlatFeeCalculator public feeCalculator;
    address public feeRecipient = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
    address public empty = address(0);

    function setUp() public {
        feeCalculator = new FlatFeeCalculator();
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

    function testSetFeeBasisPoints(uint256 basisPoints) public {
        vm.assume(basisPoints > 0);
        vm.assume(basisPoints < 10000);

        feeCalculator.setFeeBasisPoints(basisPoints);

        assertEq(feeCalculator.feeBasisPoints(), basisPoints);
    }

    function testSetFeeBasisPoints_OutOfRange_Reverts(uint256 basisPoints) public {
        vm.assume(basisPoints >= 10000);

        vm.expectRevert("Fee basis points should be less than 10000");
        feeCalculator.setFeeBasisPoints(basisPoints);
    }

    function testCalculateDepositFeesNormalCase() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100 * 1e18;

        // Act
        FeeDistribution memory feeDistribution = feeCalculator.calculateDepositFees(empty, empty, depositAmount);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(feeDistribution.recipients.length, feeDistribution.shares.length, "array length mismatch");
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 3000000000000000000);
    }

    function testCalculateRedemptionFeesNormalCase() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 100 * 1e18;
        address[] memory tco2s = new address[](1);
        tco2s[0] = empty;
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        // Act
        FeeDistribution memory feeDistribution = feeCalculator.calculateRedemptionFees(empty, tco2s, redemptionAmounts);
        address[] memory recipients = feeDistribution.recipients;
        uint256[] memory fees = feeDistribution.shares;

        // Assert
        assertEq(feeDistribution.recipients.length, feeDistribution.shares.length, "array length mismatch");
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 3000000000000000000);
    }

    function testCalculateRedemptionFeesDustAmount_ShouldThrow() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1;

        // Act
        vm.expectRevert("Fee must be greater than 0");
        FeeDistribution memory feeDistribution = feeCalculator.calculateDepositFees(empty, empty, depositAmount);
    }

    function testCalculateDepositFee_TCO2(uint256 depositAmount) public {
        // Arrange
        vm.assume(depositAmount > 100);
        vm.assume(depositAmount < 1e18 * 1e18);
        // Act
        FeeDistribution memory feeDistribution = feeCalculator.calculateDepositFees(empty, empty, depositAmount);

        uint256 expected = depositAmount * feeCalculator.feeBasisPoints() / 10000;

        assertEq(feeDistribution.shares[0], expected);
    }

    function testCalculateDepositFee_ERC1155(uint256 depositAmount) public {
        // Arrange
        vm.assume(depositAmount > 100);
        vm.assume(depositAmount < 1e18 * 1e18);
        // Act
        FeeDistribution memory feeDistribution = feeCalculator.calculateDepositFees(empty, empty, 0, depositAmount);

        uint256 expected = depositAmount * feeCalculator.feeBasisPoints() / 10000;

        assertEq(feeDistribution.shares[0], expected);
    }

    function testCalculateRedemptionAmount_TCO2(uint256 redemptionAmount) public {
        // Arrange
        vm.assume(redemptionAmount > 100);
        vm.assume(redemptionAmount < 1e18 * 1e18);
        // Act
        address[] memory tco2s = new address[](1);
        tco2s[0] = empty;
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        FeeDistribution memory feeDistribution = feeCalculator.calculateRedemptionFees(empty, tco2s, redemptionAmounts);

        uint256 expected = redemptionAmount * feeCalculator.feeBasisPoints() / 10000;

        assertEq(feeDistribution.shares[0], expected);
    }

    function testCalculateRedemptionAmount_ERC1155(uint256 redemptionAmount) public {
        // Arrange
        vm.assume(redemptionAmount > 100);
        vm.assume(redemptionAmount < 1e18 * 1e18);
        // Act
        address[] memory erc1155s = new address[](1);
        erc1155s[0] = empty;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        uint256[] memory redemptionAmounts = new uint256[](1);
        redemptionAmounts[0] = redemptionAmount;

        FeeDistribution memory feeDistribution =
            feeCalculator.calculateRedemptionFees(empty, erc1155s, tokenIds, redemptionAmounts);

        uint256 expected = redemptionAmount * feeCalculator.feeBasisPoints() / 10000;

        assertEq(feeDistribution.shares[0], expected);
    }
}
