// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {SafeCallback} from "@uniswap/v4-periphery/src/base/SafeCallback.sol";
import {CalldataDecoder} from "@uniswap/v4-periphery/src/libraries/CalldataDecoder.sol";
import {ActionConstants} from "@uniswap/v4-periphery/src/libraries/ActionConstants.sol";

/// @notice Abstract contract for performing a combination of actions on Uniswap v4.
/// @dev Suggested uint256 action values are defined in Actions.sol, however any definition can be used
abstract contract BaseActionsRouterV4 is SafeCallback {
    using CalldataDecoder for bytes;

    /// @notice emitted when different numbers of parameters and actions are provided
    error InputLengthMismatchV4();

    /// @notice emitted when an inheriting contract does not support an action
    error UnsupportedActionV4(uint256 action);

    constructor(IPoolManager _poolManager) SafeCallback(_poolManager) {}

    /// @notice internal function that triggers the execution of a set of actions on v4
    /// @dev inheriting contracts should call this function to trigger execution
    function _executeActionsV4(bytes calldata unlockData) internal {
        poolManager.unlock(unlockData);
    }

    /// @notice function that is called by the PoolManager through the SafeCallback.unlockCallback
    /// @param data Abi encoding of (bytes actions, bytes[] params)
    /// where params[i] is the encoded parameters for actions[i]
    function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
        // abi.decode(data, (bytes, bytes[]));
        (bytes calldata actions, bytes[] calldata params) = data.decodeActionsRouterParams();
        _executeActionsWithoutUnlock(actions, params);
        return "";
    }

    function _executeActionsWithoutUnlock(bytes calldata actions, bytes[] calldata params) internal {
        uint256 numActions = actions.length;
        if (numActions != params.length) revert InputLengthMismatchV4();

        for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
            uint256 action = uint8(actions[actionIndex]);

            _handleActionV4(action, params[actionIndex]);
        }
    }

    /// @notice function to handle the parsing and execution of an action and its parameters
    function _handleActionV4(uint256 action, bytes calldata params) internal virtual;

    /// @notice function that returns address considered executor of the actions
    /// @dev The other context functions, _msgData and _msgValue, are not supported by this contract
    /// In many contracts this will be the address that calls the initial entry point that calls `_executeActions`
    /// `msg.sender` shouldn't be used, as this will be the v4 pool manager contract that calls `unlockCallback`
    /// If using ReentrancyLock.sol, this function can return _getLocker()
    function msgSenderV4() public view virtual returns (address);

    /// @notice Calculates the address for a action
    function _mapRecipientV4(address recipient) internal view returns (address) {
        if (recipient == ActionConstants.MSG_SENDER) {
            return msgSenderV4();
        } else if (recipient == ActionConstants.ADDRESS_THIS) {
            return address(this);
        } else {
            return recipient;
        }
    }

    /// @notice Calculates the payer for an action
    function _mapPayerV4(bool payerIsUser) internal view returns (address) {
        return payerIsUser ? msgSenderV4() : address(this);
    }
}
