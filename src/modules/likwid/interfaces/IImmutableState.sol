// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVault} from "@likwid-fi/core/interfaces/IVault.sol";

/// @title IImmutableState
/// @notice Interface for the ImmutableState contract
interface IImmutableState {
    /// @notice The Uniswap v4 Vault contract
    function vault() external view returns (IVault);
}
