// SPDX-FileCopyrightText: 2024 Toucan Protocol
//
// SPDX-License-Identifier: UNLICENSED

// If you encounter a vulnerability or an issue, please contact <info@neutralx.com>
pragma solidity ^0.8.13;

/// @title IPool
/// @author Neutral Labs Inc.
/// @notice This interface defines methods exposed by the Pool
interface IPool {
    /// @notice Exposes the total TCO2 supply, tracked as the aggregation of deposit,
    /// redemption and bridge actions
    /// @return supply Current supply
    function totalTCO2Supply() external view returns (uint256 supply);

    /// @notice Exposes the total TCO2 supply of a project in a pool,
    /// tracked as the aggregation of deposit, redemmption and bridge actions
    /// @param projectTokenId The token id of the project as it's tracked
    /// in the CarbonProjects contract
    /// @return supply Current supply of a project in the pool
    function totalPerProjectTCO2Supply(uint256 projectTokenId) external view returns (uint256 supply);
}
