// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {FeeCalculator} from "../src/FeeCalculator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockPool is IERC20 {
    uint256 private _totalSupply;

    function totalSupply() external view returns (uint256){
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

    function balanceOf(address account) external view returns (uint256){
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

    function totalSupply() external view returns (uint256){
        return 0;
    }
}

contract FeeCalculatorTest is Test {
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

    function testCalculateDepositFeesNormalCase() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000*1e18);
        mockToken.setTokenBalance(address(mockPool), 500*1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 42930597295197661532);
    }

    function testCalculateDepositFeesComplicatedCase() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 932*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(53461*1e18);
        mockToken.setTokenBalance(address(mockPool), 15462*1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 72036833304441376295);
    }

    function testCalculateDepositFees_DepositOfOneWei_ZeroFee() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 0);//fee gets round down to zero for extremely small deposit of one wei
    }

    function testCalculateDepositFees_DepositOfHundredWei_FeesWronglyCappedAt75Percent() public {
        //Note! This is a bug, where a very small deposit to a very large pool
        //causes a == b because of precision limited by ratioDenominator in FeeCalculator

        // Arrange
        // Set up your test data
        uint256 depositAmount = 100;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 75);//most probably a bug
    }

    function testCalculateDepositFees_FuzzyExtremelySmallDepositsToLargePool_FeesWronglyCappedAt75Percent(uint256 depositAmount) public {
        vm.assume(depositAmount <= 1e-7 * 1e18);
        vm.assume(depositAmount >= 10);

        //Note! This is a bug, where a very small deposit to a very large pool
        //causes a == b because of precision limited by ratioDenominator in FeeCalculator

        // Arrange
        // Set up your test data


        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], (3 * depositAmount)/4);//most probably a bug
    }

    function testCalculateDepositFees_DepositOfHundredThousandsPartOfOne_NonzeroFee() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1e-5 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 30000000040);
    }

    function testCalculateDepositFees_DepositOfOne_NormalFee() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1e5 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e4 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 3000405020250060);
    }


    function testCalculateDepositFees_HugeTotalLargeCurrentSmallDeposit() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 1 * 1e18;

        // Set up mock pool
        mockPool.setTotalSupply(100 * 1e6 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 1e6 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 3000004454552);
    }

    function testCalculateDepositFees_ZeroDepositZeroFees() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 0;

        // Set up mock pool
        mockPool.setTotalSupply(1000*1e18);
        mockToken.setTokenBalance(address(mockPool), 500*1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 0);
    }

    function testCalculateDepositFees_ZeroTotalCappedFeesAt75Percent() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(0);
        mockToken.setTokenBalance(address(mockPool), 0);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 75 * 1e18);
    }

    function testCalculateDepositFees_TotalEqualCurrentFeesCappedAt75Percent() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000);
        mockToken.setTokenBalance(address(mockPool), 1000);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 75 * 1e18);
    }

    function testCalculateDepositFees_ZeroCurrentNormalFees() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000*1e18);
        mockToken.setTokenBalance(address(mockPool), 0);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
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


        // Set up mock pool
        mockPool.setTotalSupply(total);
        mockToken.setTokenBalance(address(mockPool), current);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
    }
}
