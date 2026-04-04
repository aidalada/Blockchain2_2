// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "../src/MockOracle.sol";
import "../src/SimpleToken.sol";

contract LendingPoolTest is Test {
    LendingPool pool;
    MockOracle oracle;
    SimpleToken colToken;
    SimpleToken borToken;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        colToken = new SimpleToken();
        borToken = new SimpleToken();
        
        oracle = new MockOracle(2 ether); 
        pool = new LendingPool(address(colToken), address(borToken), address(oracle));

        borToken.mint(address(pool), 100000 ether);

        colToken.mint(alice, 1000 ether);
        borToken.mint(bob, 5000 ether); 

        vm.startPrank(alice);
        colToken.approve(address(pool), type(uint256).max);
        borToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        borToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    // 1. Deposit flow
    function test_Deposit() public {
        vm.prank(alice);
        pool.deposit(100 ether);
        
        (uint256 col, , ) = pool.positions(alice);
        assertEq(col, 100 ether);
    }

    // 2. Borrow within LTV limits
    function test_BorrowWithinLTV() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        
        pool.borrow(100 ether); 
        vm.stopPrank();

        (, uint256 debt, ) = pool.positions(alice);
        assertEq(debt, 100 ether);
        assertEq(borToken.balanceOf(alice), 100 ether);
    }

    // 3. Borrow exceeding LTV limits (Edge Case)
    function test_RevertIf_BorrowExceedsLTV() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        
        vm.expectRevert("Health factor too low");
        pool.borrow(160 ether);
        vm.stopPrank();
    }

    // 4. Repayment (partial)
    function test_RepayPartial() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(100 ether);
        
        pool.repay(40 ether);
        vm.stopPrank();

        (, uint256 debt, ) = pool.positions(alice);
        assertEq(debt, 60 ether);
    }

    // 5. Repayment (full)
    function test_RepayFull() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(100 ether);
        
        pool.repay(150 ether);
        vm.stopPrank();

        (, uint256 debt, ) = pool.positions(alice);
        assertEq(debt, 0);
    }

    // 6. Deposit and Withdrawal flow
    function test_WithdrawAllowed() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.withdraw(50 ether);
        vm.stopPrank();

        (uint256 col, , ) = pool.positions(alice);
        assertEq(col, 50 ether);
    }

    // 7. Withdraw while having outstanding debt (Edge case)
    function test_RevertIf_WithdrawLowersHealthFactor() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(150 ether); 

        vm.expectRevert("Health factor too low");
        pool.withdraw(10 ether);
        vm.stopPrank();
    }

    // 8. Borrow with zero collateral (Edge case)
    function test_RevertIf_BorrowWithZeroCollateral() public {
        vm.prank(alice);
        vm.expectRevert("Health factor too low");
        pool.borrow(10 ether);
    }

    // 9. Interest accrual over time
    function test_InterestAccrual() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        pool.deposit(1 wei);

        (, uint256 debt, ) = pool.positions(alice);
        assertEq(debt, 110 ether);
    }

    // 10. Liquidation scenario: simulate price drop
    function test_LiquidationWorksOnPriceDrop() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(140 ether); 
        vm.stopPrank();

        oracle.setPrice(1.5 ether);

        
        uint256 bobColBefore = colToken.balanceOf(bob);
        
        vm.prank(bob);
        pool.liquidate(alice);

        (, uint256 debt, uint256 remainingCol) = pool.positions(alice);
        
        assertEq(debt, 0); 
        assertTrue(colToken.balanceOf(bob) > bobColBefore);
        assertTrue(remainingCol < 100 ether);
    }
}