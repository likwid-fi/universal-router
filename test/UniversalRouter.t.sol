// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {UniversalRouter} from "../src/UniversalRouter.sol";

contract UniversalRouterTest is Test {
    UniversalRouter public counter;

    function setUp() public {
        counter = new UniversalRouter();
        counter.setNumber(0);
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
