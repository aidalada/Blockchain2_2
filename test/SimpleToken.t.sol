// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SimpleToken.sol";

contract SimpleTokenTest is Test {
    SimpleToken token;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        token = new SimpleToken();
        token.mint(alice, 1000 ether);

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = token.transfer.selector;
        selectors[1] = token.transferFrom.selector;
        selectors[2] = token.approve.selector;

        targetSelector(FuzzSelector({
            addr: address(token),
            selectors: selectors
        }));
    }



    // 1. Тест успешного минта
    function test_MintSuccess() public {
        token.mint(bob, 500 ether);
        assertEq(token.balanceOf(bob), 500 ether);
        assertEq(token.totalSupply(), 1500 ether);
    }

    // 2. Тест: только владелец может минтить (Edge case)
    function test_RevertIf_MintNotOwner() public {
        vm.expectRevert("Not owner");
        vm.prank(alice);
        token.mint(bob, 500 ether);
    }

    // 3. Тест успешного перевода (Transfer)
    function test_TransferSuccess() public {
        vm.prank(alice);
        bool success = token.transfer(bob, 200 ether);
        assertTrue(success);
        assertEq(token.balanceOf(alice), 800 ether);
        assertEq(token.balanceOf(bob), 200 ether);
    }

    // 4. Тест: перевод больше, чем есть на балансе (Edge case)
    function test_RevertIf_TransferInsufficientBalance() public {
        vm.expectRevert("Insufficient balance");
        vm.prank(alice);
        token.transfer(bob, 2000 ether); // У Алисы только 1000
    }

    // 5. Тест: перевод на нулевой адрес (Edge case)
    function test_RevertIf_TransferToZeroAddress() public {
        vm.expectRevert("Transfer to zero address");
        vm.prank(alice);
        token.transfer(address(0), 100 ether);
    }

    // 6. Тест успешного Approve
    function test_ApproveSuccess() public {
        vm.prank(alice);
        bool success = token.approve(bob, 300 ether);
        assertTrue(success);
        assertEq(token.allowance(alice, bob), 300 ether);
    }

    // 7. Тест: Approve на нулевой адрес (Edge case)
    function test_RevertIf_ApproveToZeroAddress() public {
        vm.expectRevert("Approve to zero address");
        vm.prank(alice);
        token.approve(address(0), 100 ether);
    }

    // 8. Тест успешного TransferFrom
    function test_TransferFromSuccess() public {
        vm.prank(alice);
        token.approve(bob, 300 ether);

        vm.prank(bob);
        bool success = token.transferFrom(alice, bob, 200 ether);
        assertTrue(success);
        assertEq(token.balanceOf(alice), 800 ether);
        assertEq(token.balanceOf(bob), 200 ether);
        assertEq(token.allowance(alice, bob), 100 ether);
    }

    // 9. Тест: TransferFrom без достаточного Allowance (Edge case)
    function test_RevertIf_TransferFromInsufficientAllowance() public {
        vm.prank(alice);
        token.approve(bob, 100 ether);

        vm.expectRevert("Insufficient allowance");
        vm.prank(bob);
        token.transferFrom(alice, bob, 200 ether); // allowance только 100
    }

    // 10. Тест перевода 0 токенов (Edge case)
    function test_TransferZeroTokens() public {
        vm.prank(alice);
        bool success = token.transfer(bob, 0);
        assertTrue(success);
        assertEq(token.balanceOf(alice), 1000 ether);
        assertEq(token.balanceOf(bob), 0);
    }

    function testFuzz_Transfer(uint256 amount) public {
        vm.assume(amount <= 1000 ether);
        
        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(alice), 1000 ether - amount);
        assertEq(token.balanceOf(bob), amount);
    }

 
    
    function invariant_TotalSupplyRemainsConstant() public view {
        assertEq(token.totalSupply(), 1000 ether);
    }

    function invariant_NoAddressCanHaveMoreThanTotalSupply() public view {
        assertTrue(token.balanceOf(alice) <= token.totalSupply());
        assertTrue(token.balanceOf(bob) <= token.totalSupply());
    }
}