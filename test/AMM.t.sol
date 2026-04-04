// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/SimpleToken.sol";
import "../src/LPToken.sol";

contract AMMTest is Test {
    AMM amm;
    SimpleToken token0;
    SimpleToken token1;
    LPToken lpToken;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        token0 = new SimpleToken();
        token1 = new SimpleToken();
        amm = new AMM(address(token0), address(token1));
        lpToken = amm.lpToken();

        token0.mint(alice, 100000 ether);
        token1.mint(alice, 100000 ether);
        token0.mint(bob, 100000 ether);
        token1.mint(bob, 100000 ether);

        vm.startPrank(alice);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    // 1. Add liquidity (first provider)
    function test_AddLiquidityFirstProvider() public {
        vm.prank(alice);
        uint256 shares = amm.addLiquidity(1000 ether, 1000 ether, 0);
        assertEq(shares, 1000 ether);
        assertEq(lpToken.balanceOf(alice), 1000 ether);
        assertEq(amm.reserve0(), 1000 ether);
        assertEq(amm.reserve1(), 1000 ether);
    }

    // 2. Add liquidity (subsequent providers)
    function test_AddLiquiditySubsequentProvider() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);

        vm.prank(bob);
        uint256 shares = amm.addLiquidity(500 ether, 500 ether, 0);
        assertEq(shares, 500 ether);
        assertEq(amm.reserve0(), 1500 ether);
    }

    // 3. Remove liquidity (partial)
    function test_RemoveLiquidityPartial() public {
        vm.startPrank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);
        (uint256 amt0, uint256 amt1) = amm.removeLiquidity(500 ether, 0, 0);
        vm.stopPrank();

        assertEq(amt0, 500 ether);
        assertEq(amt1, 500 ether);
        assertEq(amm.reserve0(), 500 ether);
    }

    // 4. Remove liquidity (full)
    function test_RemoveLiquidityFull() public {
        vm.startPrank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);
        (uint256 amt0, uint256 amt1) = amm.removeLiquidity(1000 ether, 0, 0);
        vm.stopPrank();

        assertEq(amt0, 1000 ether);
        assertEq(amt1, 1000 ether); 
        assertEq(amm.reserve0(), 0);
        assertEq(lpToken.totalSupply(), 0);
    }

    // 5. Swap tokenA -> tokenB
    function test_SwapToken0ForToken1() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);

        uint256 bobBalBefore = token1.balanceOf(bob);
        vm.prank(bob);
        amm.swap(address(token0), 10 ether, 0);

        assertTrue(token1.balanceOf(bob) > bobBalBefore);
    }

    // 6. Swap tokenB -> tokenA
    function test_SwapToken1ForToken0() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);

        uint256 bobBalBefore = token0.balanceOf(bob);
        vm.prank(bob);
        amm.swap(address(token1), 10 ether, 0);

        assertTrue(token0.balanceOf(bob) > bobBalBefore);
    }

    // 7. Verify k remains constant (or increases due to fees) after swaps
    function test_VerifyKIncreasesAfterSwap() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);
        
        uint256 kBefore = amm.reserve0() * amm.reserve1();

        vm.prank(bob);
        amm.swap(address(token0), 100 ether, 0);

        uint256 kAfter = amm.reserve0() * amm.reserve1();
        assertTrue(kAfter > kBefore, "k should increase due to 0.3% fee");
    }

    // 8. Slippage protection: revert on addLiquidity
    function test_RevertIf_SlippageAddLiquidity() public {
        vm.prank(alice);
        vm.expectRevert("Slippage: insufficient LP tokens minted");
        amm.addLiquidity(100 ether, 100 ether, 101 ether); 
    }

    // 9. Slippage protection: revert on removeLiquidity
    function test_RevertIf_SlippageRemoveLiquidity() public {
        vm.startPrank(alice);
        amm.addLiquidity(100 ether, 100 ether, 0);
        vm.expectRevert("Slippage: insufficient token0 out");
        amm.removeLiquidity(50 ether, 51 ether, 0);
        vm.stopPrank();
    }

    // 10. Slippage protection: revert on swap
    function test_RevertIf_SlippageSwap() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);

        vm.prank(bob);
        vm.expectRevert("Slippage: insufficient output amount");
        amm.swap(address(token0), 10 ether, 11 ether); 
    }

    // 11. Edge case: Zero amounts on addLiquidity
    function test_RevertIf_ZeroAmountAddLiquidity() public {
        vm.prank(alice);
        vm.expectRevert("Amounts must be > 0");
        amm.addLiquidity(0, 100 ether, 0);
    }

    // 12. Edge case: Zero amount on swap
    function test_RevertIf_ZeroAmountSwap() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);

        vm.prank(bob);
        vm.expectRevert("Amount in must be > 0");
        amm.swap(address(token0), 0, 0);
    }

    // 13. Edge case: Single-sided liquidity (unbalanced ratio limits LP output)
    function test_SingleSidedLiquidityAttempt() public {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether, 0);

        vm.prank(bob);
        uint256 shares = amm.addLiquidity(1000 ether, 10 ether, 0);
        
        assertEq(shares, 10 ether); 
    }

    // 14. Edge case: Large swap causing high price impact
    function test_HighPriceImpact() public {
        vm.prank(alice);
        amm.addLiquidity(100 ether, 100 ether, 0);

        vm.prank(bob);
        uint256 out = amm.swap(address(token0), 100 ether, 0);
        assertTrue(out < 50 ether); // Price impact > 50%
    }


    function testFuzz_Swap(uint256 amountIn) public {
        vm.assume(amountIn > 10000 && amountIn <= 10000 ether);

        vm.prank(alice);
        amm.addLiquidity(50000 ether, 50000 ether, 0);

        uint256 bobBal0Before = token0.balanceOf(bob);
        uint256 bobBal1Before = token1.balanceOf(bob);

        vm.prank(bob);
        uint256 amountOut = amm.swap(address(token0), amountIn, 0);

        assertEq(token0.balanceOf(bob), bobBal0Before - amountIn);
        assertEq(token1.balanceOf(bob), bobBal1Before + amountOut);
     
        assertTrue(amountOut > 0);
    }
}