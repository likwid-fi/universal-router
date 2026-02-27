// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolKey as PoolKeyInfinity} from "infinity-core/src/types/PoolKey.sol";

interface IMixedQuoter {
    struct QuoteMixedInfiExactSingleParams {
        PoolKeyInfinity poolKey;
        bytes hookData;
    }

    struct QuoteMixedV4ExactSingleParams {
        PoolKey poolKey;
        bytes hookData;
    }

    struct QuoteExactInputSingleStableParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 flag;
    }

    struct QuoteExactOutputSingleStableParams {
        address tokenIn;
        address tokenOut;
        uint256 amountOut;
        uint256 flag;
    }
}
