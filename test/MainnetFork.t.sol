// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract MainnetForkTest is Test {
    uint256 mainnetFork;
    
    string MAINNET_RPC_URL = "https://eth.llamarpc.com";

    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Router02 router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    address alice = address(0x1234);

    function setUp() public {
        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL);
    }

    // 1. Тест: Чтение общего предложения USDC с реального контракта
        function test_ReadUSDCTotalSupply() public view {
        uint256 totalSupply = usdc.totalSupply();
        
        assertGt(totalSupply, 0, "USDC total supply should be > 0");
        
        console.log("Real USDC Total Supply:", totalSupply);
    }

    // 2. Тест: Симуляция свопа на Uniswap V2 (WETH -> USDC)
    function test_SimulateUniswapSwap() public {
        deal(address(weth), alice, 10 ether);

        vm.startPrank(alice);

        weth.approve(address(router), 1 ether);

        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(usdc);

        uint256 usdcBalanceBefore = usdc.balanceOf(alice);
        console.log("USDC balance BEFORE swap:", usdcBalanceBefore);

        router.swapExactTokensForTokens(
            1 ether, 
            0,       
            path,
            alice,
            block.timestamp + 100 
        );

        uint256 usdcBalanceAfter = usdc.balanceOf(alice);
        console.log("USDC balance AFTER swap:", usdcBalanceAfter);

        vm.stopPrank();

        assertGt(usdcBalanceAfter, usdcBalanceBefore, "Swap failed!");
        console.log("Successfully swapped 1 WETH for", (usdcBalanceAfter - usdcBalanceBefore) / 1e6, "USDC");
    }
}