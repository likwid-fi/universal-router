// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ActionConstants} from "@uniswap/v4-periphery/src/libraries/ActionConstants.sol";
import {IVault} from "@likwid-fi/core/interfaces/IVault.sol";
import {Currency} from "@likwid-fi/core/types/Currency.sol";

/// @notice Abstract contract used to sync, send, and settle funds to the pool manager
/// @dev Note that sync() is called before any erc-20 transfer in `settle`.
abstract contract DeltaResolver {
    /// @notice Emitted trying to settle a positive delta.
    error DeltaNotPositiveLikwidV2(Currency currency);
    /// @notice Emitted trying to take a negative delta.
    error DeltaNotNegativeLikwidV2(Currency currency);
    /// @notice Emitted when the contract does not have enough balance to wrap or unwrap.
    error InsufficientBalanceLikwidV2();

    IVault public immutable likwidVault;

    /// @dev uint256 internal constant CURRENCY_DELTA = uint256(keccak256("CURRENCY_DELTA")) - 1;
    uint256 internal constant CURRENCY_DELTA = 0xd9bd4e389ed8cbf1cf078cf6e39b899ba664e27ad65dbc00c572373981e91d5e;

    /// @dev ref: https://docs.soliditylang.org/en/v0.8.24/internals/layout_in_storage.html#mappings-and-dynamic-arrays
    /// simulating mapping index but with a single hash
    /// save one keccak256 hash compared to built-in nested mapping
    function _currencyDeltaSlot(Currency currency, address target) internal pure returns (bytes32 hashSlot) {
        hashSlot = keccak256(abi.encode(currency, target, CURRENCY_DELTA));
    }

    function currencyDelta(Currency currency, address target) internal view returns (int256) {
        bytes32 hashSlot = _currencyDeltaSlot(currency, target);
        return int256(uint256(likwidVault.exttload(hashSlot)));
    }

    /// @notice Take an amount of currency out of the Vault
    /// @param currency Currency to take
    /// @param recipient Address to receive the currency
    /// @param amount Amount to take
    /// @dev Returns early if the amount is 0
    function _take(Currency currency, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        likwidVault.take(currency, recipient, amount);
    }

    /// @notice Pay and settle a currency to the Vault
    /// @dev The implementing contract must ensure that the `payer` is a secure address
    /// @param currency Currency to settle
    /// @param payer Address of the payer
    /// @param amount Amount to send
    /// @dev Returns early if the amount is 0
    function _settle(Currency currency, address payer, uint256 amount) internal {
        if (amount == 0) return;

        likwidVault.sync(currency);
        if (currency.isAddressZero()) {
            likwidVault.settle{value: amount}();
        } else {
            _pay(currency, payer, amount);
            likwidVault.settle();
        }
    }

    /// @notice Abstract function for contracts to implement paying tokens to the Vault
    /// @dev The recipient of the payment should be the Vault
    /// @param token The token to settle. This is known not to be the native currency
    /// @param payer The address who should pay tokens
    /// @param amount The number of tokens to send
    function _pay(Currency token, address payer, uint256 amount) internal virtual;

    /// @notice Obtain the full amount owed by this contract (negative delta)
    /// @param currency Currency to get the delta for
    /// @return amount The amount owed by this contract as a uint256
    function _getFullDebt(Currency currency) internal view returns (uint256 amount) {
        int256 _amount = currencyDelta(currency, address(this));
        // If the amount is positive, it should be taken not settled.
        if (_amount > 0) revert DeltaNotNegativeLikwidV2(currency);
        // Casting is safe due to limits on the total supply of a pool
        amount = uint256(-_amount);
    }

    /// @notice Obtain the full credit owed to this contract (positive delta)
    /// @param currency Currency to get the delta for
    /// @return amount The amount owed to this contract as a uint256
    function _getFullCredit(Currency currency) internal view returns (uint256 amount) {
        int256 _amount = currencyDelta(currency, address(this));
        // If the amount is negative, it should be settled not taken.
        if (_amount < 0) revert DeltaNotPositiveLikwidV2(currency);
        amount = uint256(_amount);
    }

    /// @notice Calculates the amount for a settle action
    function _mapSettleAmount(uint256 amount, Currency currency) internal view returns (uint256) {
        if (amount == ActionConstants.CONTRACT_BALANCE) {
            return currency.balanceOfSelf();
        } else if (amount == ActionConstants.OPEN_DELTA) {
            return _getFullDebt(currency);
        } else {
            return amount;
        }
    }

    /// @notice Calculates the amount for a take action
    function _mapTakeAmount(uint256 amount, Currency currency) internal view returns (uint256) {
        if (amount == ActionConstants.OPEN_DELTA) {
            return _getFullCredit(currency);
        } else {
            return amount;
        }
    }

    /// @notice Calculates the sanitized amount before wrapping/unwrapping.
    /// @param inputCurrency The currency, either native or wrapped native, that this contract holds
    /// @param amount The amount to wrap or unwrap. Can be CONTRACT_BALANCE, OPEN_DELTA or a specific amount
    /// @param outputCurrency The currency after the wrap/unwrap that the user may owe a balance in on the poolManager
    function _mapWrapUnwrapAmount(Currency inputCurrency, uint256 amount, Currency outputCurrency)
        internal
        view
        returns (uint256)
    {
        // if wrapping, the balance in this contract is in ETH
        // if unwrapping, the balance in this contract is in WETH
        uint256 balance = inputCurrency.balanceOf(address(this));
        if (amount == ActionConstants.CONTRACT_BALANCE) {
            // return early to avoid unnecessary balance check
            return balance;
        }
        if (amount == ActionConstants.OPEN_DELTA) {
            // if wrapping, the open currency on the PoolManager is WETH.
            // if unwrapping, the open currency on the PoolManager is ETH.
            // note that we use the DEBT amount. Positive deltas can be taken and then wrapped.
            amount = _getFullDebt(outputCurrency);
        }
        if (amount > balance) revert InsufficientBalanceLikwidV2();
        return amount;
    }
}
