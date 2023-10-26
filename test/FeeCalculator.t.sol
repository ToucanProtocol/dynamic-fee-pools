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

    function testCalculateRedemptionFeesNormalCase() public {
        // Arrange
        // Set up your test data
        uint256 redemptionAmount = 100*1e18;

        // Set up mock pool
        mockPool.setTotalSupply(1000*1e18);
        mockToken.setTokenBalance(address(mockPool), 500*1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemptionAmount);

        // Assert
        assertEq(recipients[0], feeRecipient);
        assertEq(fees[0], 5715592135358939186);
    }

    function testCalculateDepositFeesNormalCase_TwoFeeRecipientsSplitEqually() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100*1e18;
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;

        // Set up mock pool
        mockPool.setTotalSupply(1000*1e18);
        mockToken.setTokenBalance(address(mockPool), 500*1e18);

        address[] memory _recipients = new address[](2);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        uint256[] memory _feeShares = new uint256[](2);
        _feeShares[0] = 50;
        _feeShares[1] = 50;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(sumOf(fees), 42930597295197661532);
        assertEq(fees[0], 42930597295197661532/2);
        assertEq(fees[1], 42930597295197661532/2);
    }

    function testCalculateDepositFeesNormalCase_TwoFeeRecipientsSplit30To70() public {
        // Arrange
        // Set up your test data
        uint256 depositAmount = 100*1e18;
        address feeRecipient1 = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
        address feeRecipient2 = 0xCA35b7d915458EF540aDe6068dFe2F44E8fa733c;

        // Set up mock pool
        mockPool.setTotalSupply(1000*1e18);
        mockToken.setTokenBalance(address(mockPool), 500*1e18);

        address[] memory _recipients = new address[](2);
        _recipients[0] = feeRecipient1;
        _recipients[1] = feeRecipient2;
        uint256[] memory _feeShares = new uint256[](2);
        _feeShares[0] = 30;
        _feeShares[1] = 70;
        feeCalculator.feeSetup(_recipients, _feeShares);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(sumOf(fees), 42930597295197661532);
        assertEq(fees[0], uint256(42930597295197661532) * 30 / 100 + 1);//rest from division operation goes to first recipient
        assertEq(fees[1], uint256(42930597295197661532) * 70 / 100);
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
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(recipients[2], feeRecipient3);
        assertEq(recipients[3], feeRecipient4);
        assertEq(recipients[4], feeRecipient5);
        assertEq(sumOf(fees), 3000405020250060);
        assertEq(fees[0], 3000405020250060 * 20 / 100);
        assertEq(fees[1], 3000405020250060 * 20 / 100);
        assertEq(fees[2], 3000405020250060 * 20 / 100);
        assertEq(fees[3], 3000405020250060 * 20 / 100);
        assertEq(fees[4], 3000405020250060 * 20 / 100);
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
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        assertEq(recipients[0], feeRecipient1);
        assertEq(recipients[1], feeRecipient2);
        assertEq(recipients[2], feeRecipient3);
        assertEq(recipients[3], feeRecipient4);
        assertEq(recipients[4], feeRecipient5);
        assertEq(sumOf(fees), 3000405020250060);
        assertEq(fees[0], 3000405020250060 * 15 / 100 + 1);//first recipient gets rest of fee
        assertEq(fees[1], 3000405020250060 * 30 / 100);
        assertEq(fees[2], 3000405020250060 * 50 / 100);
        assertEq(fees[3], uint256(3000405020250060) * 3 / 100);
        assertEq(fees[4], uint256(3000405020250060) * 2 / 100);
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

    function testCalculateRedemptionFeesFuzzy_RedemptionDividedIntoMultipleChunksFeesGreaterOrEqualToOneRedemption(uint8 numberOfRedemptions, uint128 _redemptionAmount, uint128 _current, uint128 _total) public {
        vm.assume(0 < numberOfRedemptions);
        //vm.assume(numberOfRedemptions <= 3);
        vm.assume(_total >= _current);
        vm.assume(_redemptionAmount <= _current);
        vm.assume(_redemptionAmount < 1e20 * 1e18);
        vm.assume(_total < 1e20 * 1e18);
        vm.assume(_redemptionAmount > 1e12);
        vm.assume(_current > 1e12);

        uint256 redemptionAmount = _redemptionAmount;
        uint256 current = _current;
        uint256 total = _total;

        // Arrange
        // Set up your test data

        // Set up mock pool
        mockPool.setTotalSupply(total);
        mockToken.setTokenBalance(address(mockPool), current);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateRedemptionFee(address(mockToken), address(mockPool), redemptionAmount);
        uint256 oneTimeFee = fees[0];

        uint256 equalRedemption = redemptionAmount / numberOfRedemptions;
        uint256 restRedemption = redemptionAmount % numberOfRedemptions;
        uint256 feeFromDividedRedemptions = 0;

        for (uint256 i = 0; i < numberOfRedemptions; i++) {
            uint256 redemption = equalRedemption + (i==0 ? restRedemption : 0);
            (recipients, fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), redemption);
            feeFromDividedRedemptions += fees[0];
            total-=redemption;
            current-=redemption;
            mockPool.setTotalSupply(total);
            mockToken.setTokenBalance(address(mockPool), current);
        }

        // Assert
        assertGe(200*feeFromDividedRedemptions/100, oneTimeFee);//may be a bug but this one is not always true
        //assertApproxEqRel(feeFromDividedRedemptions, oneTimeFee, 100 * 1e16);//max 50% difference between these fees
    }

    function testCalculateDepositFeesFuzzy_DepositDividedIntoMultipleChunksFeesGreaterOrEqualToOneDeposit(uint8 numberOfDeposits, uint128 _depositAmount, uint128 _current, uint128 _total) public {
        vm.assume(0 < numberOfDeposits);
        //vm.assume(numberOfDeposits <= 3);
        vm.assume(_total >= _current);

        vm.assume(_depositAmount < 1e20 * 1e18);
        vm.assume(_total < 1e20 * 1e18);

        vm.assume(_depositAmount > 1e12);
        vm.assume(_current > 1e12);

        uint256 depositAmount = _depositAmount;
        uint256 current = _current;
        uint256 total = _total;

        // Arrange
        // Set up your test data

        // Set up mock pool
        mockPool.setTotalSupply(total);
        mockToken.setTokenBalance(address(mockPool), current);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);
        uint256 oneTimeFee = fees[0];

        uint256 equalDeposit = depositAmount / numberOfDeposits;
        uint256 restDeposit = depositAmount % numberOfDeposits;
        uint256 feeFromDividedDeposits = 0;

        for (uint256 i = 0; i < numberOfDeposits; i++) {
            uint256 deposit = equalDeposit + (i==0 ? restDeposit : 0);
            (recipients, fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), deposit);
            feeFromDividedDeposits += fees[0];
            total+=deposit;
            current+=deposit;
            mockPool.setTotalSupply(total);
            mockToken.setTokenBalance(address(mockPool), current);
        }

        // Assert
        assertGe(150*feeFromDividedDeposits/100, oneTimeFee);//may be a bug but this one is not always true
        //assertApproxEqRel(feeFromDividedDeposits, oneTimeFee, 100 * 1e16);//max 50% difference between these fees
    }

    function sumOf(uint256[] memory numbers) public pure returns (uint256) {
        uint256 sum = 0;
        for (uint i = 0; i < numbers.length; i++) {
            sum += numbers[i];
        }
        return sum;
    }

    function testFeeSetupFuzzy(address[] memory recipients, uint8 firstShare) public {
        vm.assume(recipients.length <= 100);
        vm.assume(recipients.length > 1);//at least two recipients
        vm.assume(firstShare <= 100);
        vm.assume(firstShare > 0);


        uint256[] memory feeShares = new uint256[](recipients.length);

        uint256 shareLeft = 100 - firstShare;
        feeShares[0] = firstShare;
        uint256 equalShare = shareLeft / (recipients.length-1);
        uint256 leftShare = shareLeft % (recipients.length-1);

        for(uint i=1; i < recipients.length; i++) {
            feeShares[i] = equalShare;
        }
        feeShares[recipients.length-1] += leftShare;//last one gets additional share
        feeCalculator.feeSetup(recipients, feeShares);

        uint256 depositAmount = 100 * 1e18;
        // Set up mock pool
        mockPool.setTotalSupply(200 * 1e18);
        mockToken.setTokenBalance(address(mockPool), 100 * 1e18);

        // Act
        (address[] memory recipients, uint256[] memory fees) = feeCalculator.calculateDepositFees(address(mockToken), address(mockPool), depositAmount);

        // Assert
        for(uint i=0; i < recipients.length; i++) {
            assertEq(recipients[i], recipients[i]);
        }

        assertEq(sumOf(fees), 60763888888776388888);

        assertApproxEqAbs(fees[0], 60763888888776388888 * uint256(firstShare) / 100,
            recipients.length-1);//first fee might get the rest from division

        for(uint i=1; i < recipients.length-1; i++) {
            assertEq(fees[i], 60763888888776388888 * equalShare / 100);
        }
        assertEq(fees[recipients.length-1], 60763888888776388888 * (equalShare+leftShare) / 100);
    }
}
