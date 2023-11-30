// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library TestUtilities {
    function sumOf(uint256[] memory numbers) internal pure returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < numbers.length; i++) {
            sum += numbers[i];
        }
        return sum;
    }
}

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

    function balanceOf(address account) external pure returns (uint256) {
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

    function totalSupply() external pure returns (uint256) {
        return 0;
    }
}
