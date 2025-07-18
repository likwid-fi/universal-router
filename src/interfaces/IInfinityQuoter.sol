// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKeyInfinity} from "../types/PoolKey.sol";
import {Currency} from "../types/Currency.sol";
import {PathKeyInfinity} from "../libraries/PathKey.sol";

/// @title IInfinityQuoter
/// @notice Interface for the InfinityQuoter contract
interface IInfinityQuoter {
    struct QuoteExactSingleParams {
        PoolKeyInfinity poolKey;
        bool zeroForOne;
        uint128 exactAmount;
        bytes hookData;
    }

    struct QuoteExactParams {
        Currency exactCurrency;
        PathKeyInfinity[] path;
        uint128 exactAmount;
    }

    /// @notice Returns the delta amounts for a given exact input swap of a single pool
    /// @param params The params for the quote, encoded as `QuoteExactSingleParams`
    /// poolKey The key for identifying a infinity pool
    /// zeroForOne If the swap is from currency0 to currency1
    /// exactAmount The desired input amount
    /// hookData arbitrary hookData to pass into the associated hooks
    /// @return amountOut The output quote for the exactIn swap
    /// @return gasEstimate Estimated gas units used for the swap
    function quoteExactInputSingle(QuoteExactSingleParams memory params)
        external
        returns (uint256 amountOut, uint256 gasEstimate);

    /// @notice Returns the last swap delta amounts for a given exact input in a list of swap
    /// @param params The params for the quote, encoded as `QuoteExactSingleParams[]`
    /// poolKey The key for identifying a infinity pool
    /// zeroForOne If the swap is from currency0 to currency1
    /// exactAmount The desired input amount
    /// hookData arbitrary hookData to pass into the associated hooks
    /// @return amountOut The last swap output quote for the exactIn swap
    /// @return gasEstimate Estimated gas units used for the swap
    function quoteExactInputSingleList(QuoteExactSingleParams[] memory params)
        external
        returns (uint256 amountOut, uint256 gasEstimate);

    /// @notice Returns the delta amounts along the swap path for a given exact input swap
    /// @param params the params for the quote, encoded as 'QuoteExactParams'
    /// currencyIn The input currency of the swap
    /// path The path of the swap encoded as PathKeys that contains currency, fee, tickSpacing, and hook info
    /// exactAmount The desired input amount
    /// @return amountOut The output quote for the exactIn swap
    /// @return gasEstimate Estimated gas units used for the swap
    function quoteExactInput(QuoteExactParams memory params)
        external
        returns (uint256 amountOut, uint256 gasEstimate);

    /// @notice Returns the delta amounts for a given exact output swap of a single pool
    /// @param params The params for the quote, encoded as `QuoteExactSingleParams`
    /// poolKey The key for identifying a infinity pool
    /// zeroForOne If the swap is from currency0 to currency1
    /// exactAmount The desired output amount
    /// hookData arbitrary hookData to pass into the associated hooks
    /// @return amountIn The input quote for the exactOut swap
    /// @return gasEstimate Estimated gas units used for the swap
    function quoteExactOutputSingle(QuoteExactSingleParams memory params)
        external
        returns (uint256 amountIn, uint256 gasEstimate);

    /// @notice Returns the delta amounts along the swap path for a given exact output swap
    /// @param params the params for the quote, encoded as 'QuoteExactParams'
    /// currencyOut The output currency of the swap
    /// path The path of the swap encoded as PathKeys that contains currency, fee, tickSpacing, and hook info
    /// exactAmount The desired output amount
    /// @return amountIn The input quote for the exactOut swap
    /// @return gasEstimate Estimated gas units used for the swap
    function quoteExactOutput(QuoteExactParams memory params)
        external
        returns (uint256 amountIn, uint256 gasEstimate);
}
