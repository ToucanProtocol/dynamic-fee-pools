// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FeeCalculator} from "../src/FeeCalculator.sol";
import {IPool} from "../src/interfaces/IPool.sol";

contract MockPool is IPool {
    uint256 public override totalSupply;
    mapping(address => uint256) public override tokenBalances;

    function setTotalSupply(uint256 _totalSupply) public {
        totalSupply = _totalSupply;
    }

    function setTokenBalance(address token, uint256 balance) public {
        tokenBalances[token] = balance;
    }
}

contract FeeCalculatorTest is Test {
    FeeCalculator public feeCalculator;
    MockPool public mockPool;

    function setUp() public {
        feeCalculator = new FeeCalculator();
        mockPool = new MockPool();
    }

    function testCalculateDepositFeesNormalCase() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 100*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000*1e18);
        mockPool.setTokenBalance(tco2, 500*1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 42930597295197661532);
    }

    function testCalculateDepositFeesComplicatedCase() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 932*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(53461*1e18);
        mockPool.setTokenBalance(tco2, 15462*1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 72036833304441376295);
    }

    function testCalculateDepositFees_DepositOfOneWei_ZeroFee() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 1;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setTokenBalance(tco2, 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 0);//fee gets round down to zero for extremely small deposit of one wei
    }

    function testCalculateDepositFees_DepositOfHundredWei_FeesWronglyCappedAt75Percent() public {
        //Note! This is a bug, where a very small deposit to a very large pool
        //causes a == b because of precision limited by ratioDenominator in FeeCalculator

        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 100;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setTokenBalance(tco2, 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 75);//most probably a bug
    }

    function testCalculateDepositFees_FuzzyExtremelySmallDepositsToLargePool_FeesWronglyCappedAt75Percent(uint256 depositAmount) public {
        vm.assume(depositAmount <= 1e-7 * 1e18);
        vm.assume(depositAmount >= 10);

        //Note! This is a bug, where a very small deposit to a very large pool
        //causes a == b because of precision limited by ratioDenominator in FeeCalculator

        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setTokenBalance(tco2, 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], (3 * depositAmount)/4);//most probably a bug
    }

    function testCalculateDepositFees_DepositOfHundredThousandsPartOfOne_NonzeroFee() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 1e-5 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setTokenBalance(tco2, 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 30000000040);
    }

    function testCalculateDepositFees_DepositOfOne_NormalFee() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockPool.setTokenBalance(tco2, 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 3000405020250060);
    }


    function testCalculateDepositFees_HugeTotalLargeCurrentSmallDeposit() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(100 * 1e6 * 1e18);
        mockPool.setTokenBalance(tco2, 1e6 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 3000004454552);
    }

    function testCalculateDepositFees_ZeroDepositZeroFees() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 0;

        // Set up mock pool
        mockPool.setTotalSupply(1000*1e18);
        mockPool.setTokenBalance(tco2, 500*1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 0);
    }

    function testCalculateDepositFees_ZeroTotalCappedFeesAt75Percent() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 100*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(0);
        mockPool.setTokenBalance(tco2, 0);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 75 * 1e18);
    }

    function testCalculateDepositFees_TotalEqualCurrentFeesCappedAt75Percent() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 100*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000);
        mockPool.setTokenBalance(tco2, 1000);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 75 * 1e18);
    }

    function testCalculateDepositFees_ZeroCurrentNormalFees() public {
        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address
        uint256 depositAmount = 100*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000*1e18);
        mockPool.setTokenBalance(tco2, 0);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
        assertEq(fees[0], 56348610067449286);
    }

    function testCalculateDepositFeesFuzzy(uint256 depositAmount, uint256 current, uint256 total) public {
        //vm.assume(depositAmount > 0);
        //vm.assume(total > 0);
        //vm.assume(current > 0);
        vm.assume(total >= current);
        vm.assume(depositAmount < 1e20 * 1e18);
        vm.assume(total < 1e20 * 1e18);

        // Arrange
        // Set up your test data
        address tco2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2; // Example address

        // Set up mock pool
        mockPool.setTotalSupply(total);
        mockPool.setTokenBalance(tco2, current);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(tco2, address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], tco2);
    }
}
