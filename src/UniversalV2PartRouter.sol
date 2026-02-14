// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

// Command implementations
import {DispatcherV2Part} from "./base/DispatcherV2Part.sol";
import {RouterParameters, RouterImmutables} from "./base/RouterImmutables.sol";
import {LikwidV2SwapRouter} from "./modules/likwid/LikwidV2SwapRouter.sol";
import {Commands} from "./libraries/Commands.sol";
import {IUniversalRouter} from "./interfaces/IUniversalRouter.sol";

contract UniversalV2PartRouter is RouterImmutables, IUniversalRouter, DispatcherV2Part {
    constructor(RouterParameters memory params) RouterImmutables(params) LikwidV2SwapRouter(params.likwidVault) {}

    modifier ensure(uint256 deadline) {
        _ensure(deadline);
        _;
    }

    function _ensure(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert TransactionDeadlinePassed();
    }

    /// @notice To receive ETH from WETH and refunds
    receive() external payable {
        if (!(msg.sender == address(WETH9) || msg.sender == address(likwidVault))) {
            revert InvalidEthSender();
        }
    }

    /// @inheritdoc IUniversalRouter
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        execute(commands, inputs);
    }

    /// @inheritdoc DispatcherV2Part
    function execute(bytes calldata commands, bytes[] calldata inputs)
        public
        payable
        override(DispatcherV2Part)
        isNotLocked
    {
        bool success;
        bytes memory output;
        uint256 numCommands = commands.length;
        if (inputs.length != numCommands) revert LengthMismatch();

        // loop through all given commands, execute them and pass along outputs as defined
        for (uint256 commandIndex = 0; commandIndex < numCommands; commandIndex++) {
            bytes1 command = commands[commandIndex];

            bytes calldata input = inputs[commandIndex];

            (success, output) = dispatch(command, input);

            if (!success && successRequired(command)) {
                revert ExecutionFailed({commandIndex: commandIndex, message: output});
            }
        }
    }

    function successRequired(bytes1 command) internal pure returns (bool) {
        return command & Commands.FLAG_ALLOW_REVERT == 0;
    }
}
