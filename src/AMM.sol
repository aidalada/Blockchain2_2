// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./LPToken.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract AMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    LPToken public immutable lpToken;

    uint256 public reserve0;
    uint256 public reserve1;

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpAmount);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpAmount);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        lpToken = new LPToken();
    }

    function _update(uint256 _reserve0, uint256 _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function addLiquidity(uint256 amount0, uint256 amount1, uint256 minLpOut) external returns (uint256 shares) {
        require(amount0 > 0 && amount1 > 0, "Amounts must be > 0");

        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        uint256 totalSupply = lpToken.totalSupply();
        
        if (totalSupply == 0) {
            shares = _sqrt(amount0 * amount1);
        } else {
            uint256 share0 = (amount0 * totalSupply) / reserve0;
            uint256 share1 = (amount1 * totalSupply) / reserve1;
            shares = share0 < share1 ? share0 : share1; 
        }

        require(shares >= minLpOut, "Slippage: insufficient LP tokens minted");
        require(shares > 0, "Shares = 0");

        lpToken.mint(msg.sender, shares);
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));

        emit LiquidityAdded(msg.sender, amount0, amount1, shares);
    }

    function removeLiquidity(uint256 shares, uint256 minAmount0, uint256 minAmount1) external returns (uint256 amount0, uint256 amount1) {
        require(shares > 0, "Shares must be > 0");
        uint256 totalSupply = lpToken.totalSupply();

        amount0 = (shares * reserve0) / totalSupply;
        amount1 = (shares * reserve1) / totalSupply;

        require(amount0 >= minAmount0, "Slippage: insufficient token0 out");
        require(amount1 >= minAmount1, "Slippage: insufficient token1 out");

        lpToken.burn(msg.sender, shares);
        _update(reserve0 - amount0, reserve1 - amount1);

        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        emit LiquidityRemoved(msg.sender, amount0, amount1, shares);
    }

    // Расчет количества токенов на выходе с учетом 0.3% комиссии
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "Amount in must be > 0");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        
        return numerator / denominator;
    }

    // Обмен токенов
    function swap(address _tokenIn, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        require(_tokenIn == address(token0) || _tokenIn == address(token1), "Invalid token");
        require(amountIn > 0, "Amount in must be > 0");

        bool isToken0 = _tokenIn == address(token0);
        IERC20 tokenIn = isToken0 ? token0 : token1;
        IERC20 tokenOut = isToken0 ? token1 : token0;
        
        uint256 reserveIn = isToken0 ? reserve0 : reserve1;
        uint256 reserveOut = isToken0 ? reserve1 : reserve0;

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= minAmountOut, "Slippage: insufficient output amount");

        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        tokenOut.transfer(msg.sender, amountOut);

        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));

        emit Swap(msg.sender, _tokenIn, amountIn, amountOut);
    }

    function _sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}