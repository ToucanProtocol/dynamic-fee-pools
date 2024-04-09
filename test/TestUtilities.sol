// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VintageData} from "../src/interfaces/ITCO2.sol";

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
    mapping(address => uint256) private _totalPerTCO2Supply;
    mapping(address => mapping(uint256 => uint256))
        private _totalPerERC1155TokenSupply;

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalTCO2Supply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalPerProjectSupply(
        address tco2
    ) external view returns (uint256) {
        return _totalPerTCO2Supply[tco2];
    }

    function totalPerProjectSupply(
        address erc1155,
        uint256 tokenId
    ) external view returns (uint256) {
        return _totalPerERC1155TokenSupply[erc1155][tokenId];
    }

    function setTotalSupply(uint256 ts) public {
        _totalSupply = ts;
    }

    function setTCO2Supply(address tco2, uint256 ts) public {
        _totalPerTCO2Supply[tco2] = ts;
    }

    function setERC1155Supply(address erc1155, uint256 tokenId, uint256 ts) public {
        _totalPerERC1155TokenSupply[erc1155][tokenId] = ts;
    }

    function allowance(
        address,
        address
    ) external pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transfer(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(
        address,
        address,
        uint256
    ) external pure override returns (bool) {
        return true;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 0;
    }
}

contract MockToken is IERC20 {
    mapping(address => uint256) public override balanceOf;

    function allowance(
        address,
        address
    ) external pure override returns (uint256) {
        return 0;
    }

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transfer(address, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(
        address,
        address,
        uint256
    ) external pure override returns (bool) {
        return true;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function getVintageData() external pure returns (VintageData memory) {
        return
            VintageData({
                name: "test",
                startTime: 0,
                endTime: 0,
                projectTokenId: 1,
                totalVintageQuantity: 0,
                isCorsiaCompliant: false,
                isCCPcompliant: false,
                coBenefits: "",
                correspAdjustment: "",
                additionalCertification: "",
                uri: "",
                registry: ""
            });
    }
}
