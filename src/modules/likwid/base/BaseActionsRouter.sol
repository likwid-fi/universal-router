// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CalldataDecoder} from "@uniswap/v4-periphery/src/libraries/CalldataDecoder.sol";
import {ActionConstants} from "@uniswap/v4-periphery/src/libraries/ActionConstants.sol";

import {DeltaResolver} from "./DeltaResolver.sol";

/// @notice Abstract contract for performing a combination of actions on Likwid v2.
/// @dev Suggested uint256 action values are defined in Actions.sol, however any definition can be used
abstract contract BaseActionsRouterLikwidV2 is DeltaResolver {
    using CalldataDecoder for bytes;

    /// @notice emitted when different numbers of parameters and actions are provided
    error InputLengthMismatchLikwidV2();

    /// @notice emitted when an inheriting contract does not support an action
    error UnsupportedActionLikwidV2(uint256 action);

    /// @notice internal function that triggers the execution of a set of actions on v4
    /// @dev inheriting contracts should call this function to trigger execution
    function _executeActionsLikwidV2(bytes calldata unlockData) internal {
        likwidVault.unlock(unlockData);
    }

    function _executeActionsWithoutUnlockLikwidV2(bytes calldata actions, bytes[] calldata params) internal {
        uint256 numActions = actions.length;
        if (numActions != params.length) revert InputLengthMismatchLikwidV2();

        for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
            uint256 action = uint8(actions[actionIndex]);

            _handleActionLikwidV2(action, params[actionIndex]);
        }
    }

    /// @notice function to handle the parsing and execution of an action and its parameters
    function _handleActionLikwidV2(uint256 action, bytes calldata params) internal virtual;

    /// @notice function that returns address considered executor of the actions
    /// @dev The other context functions, _msgData and _msgValue, are not supported by this contract
    /// In many contracts this will be the address that calls the initial entry point that calls `_executeActions`
    /// `msg.sender` shouldn't be used, as this will be the v4 pool manager contract that calls `unlockCallback`
    /// If using ReentrancyLock.sol, this function can return _getLocker()
    function msgSenderLikwidV2() public view virtual returns (address);

    /// @notice Calculates the address for a action
    function _mapRecipientLikwidV2(address recipient) internal view returns (address) {
        if (recipient == ActionConstants.MSG_SENDER) {
            return msgSenderLikwidV2();
        } else if (recipient == ActionConstants.ADDRESS_THIS) {
            return address(this);
        } else {
            return recipient;
        }
    }

    /// @notice Calculates the payer for an action
    function _mapPayerLikwidV2(bool payerIsUser) internal view returns (address) {
        return payerIsUser ? msgSenderLikwidV2() : address(this);
    }
}
