// SPDX-FileCopyrightText: 2023 Neutral Labs Inc.
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

/// @title IPool
/// @author Neutral Labs Inc.
/// @notice This interface defines methods exposed by the Pool
interface IPool {
    /// @notice Exposes the total TCO2 supply, tracked as the aggregation of deposit,
    /// redemmption and bridge actions
    /// @return supply Current supply
    function totalTCO2Supply() external view returns (uint256 supply);
}
