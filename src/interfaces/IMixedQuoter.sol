// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.26;

import {PoolKey, PoolKeyInfinity} from "../types/PoolKey.sol";

interface IMixedQuoter {
    struct QuoteMixedInfiExactInputSingleParams {
        PoolKeyInfinity poolKey;
        bytes hookData;
    }

    struct QuoteMixedV4ExactInputSingleParams {
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
