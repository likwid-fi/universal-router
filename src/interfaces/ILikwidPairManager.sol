// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PoolId} from "@likwid-fi/core/types/PoolId.sol";
import {PoolKey} from "@likwid-fi/core/types/PoolKey.sol";

interface ILikwidPairManager {
    function poolKeys(PoolId poolId) external view returns (PoolKey memory poolKey);
}
