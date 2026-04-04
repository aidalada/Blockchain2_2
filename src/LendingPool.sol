// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MockOracle.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LendingPool {
    IERC20 public immutable collateralToken;
    IERC20 public immutable borrowToken;
    MockOracle public immutable oracle;

    uint256 public constant LTV = 75; 
    uint256 public constant LIQUIDATION_BONUS = 10;
    uint256 public constant INTEREST_RATE_PER_YEAR = 10; 

    struct Position {
        uint256 collateral;
        uint256 principalDebt; 
        uint256 lastInterestUpdate;
    }

    mapping(address => Position) public positions;

    constructor(address _collateralToken, address _borrowToken, address _oracle) {
        collateralToken = IERC20(_collateralToken);
        borrowToken = IERC20(_borrowToken);
        oracle = MockOracle(_oracle);
    }

    function _accrueInterest(address user) internal {
        Position storage pos = positions[user];
        if (pos.principalDebt > 0) {
            uint256 timeElapsed = block.timestamp - pos.lastInterestUpdate;
            uint256 interest = (pos.principalDebt * INTEREST_RATE_PER_YEAR * timeElapsed) / (100 * 365 days);
            pos.principalDebt += interest;
        }
        pos.lastInterestUpdate = block.timestamp;
    }

    function getHealthFactor(address user) public view returns (uint256) {
        Position memory pos = positions[user];
        if (pos.principalDebt == 0) return type(uint256).max;

        uint256 timeElapsed = block.timestamp - pos.lastInterestUpdate;
        uint256 interest = (pos.principalDebt * INTEREST_RATE_PER_YEAR * timeElapsed) / (100 * 365 days);
        uint256 currentDebt = pos.principalDebt + interest;

        uint256 collateralValue = (pos.collateral * oracle.getPrice()) / 1e18;
        uint256 borrowCapacity = (collateralValue * LTV) / 100;
        
        return (borrowCapacity * 1e18) / currentDebt;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);
        
        collateralToken.transferFrom(msg.sender, address(this), amount);
        positions[msg.sender].collateral += amount;
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);
        require(positions[msg.sender].collateral >= amount, "Insufficient collateral");
        
        positions[msg.sender].collateral -= amount;
        
        if (positions[msg.sender].principalDebt > 0) {
            require(getHealthFactor(msg.sender) >= 1e18, "Health factor too low");
        }

        collateralToken.transfer(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);
        
        positions[msg.sender].principalDebt += amount;
        
        require(getHealthFactor(msg.sender) >= 1e18, "Health factor too low");
        
        borrowToken.transfer(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _accrueInterest(msg.sender);
        
        Position storage pos = positions[msg.sender];
        uint256 repayAmount = amount > pos.principalDebt ? pos.principalDebt : amount;
        
        borrowToken.transferFrom(msg.sender, address(this), repayAmount);
        pos.principalDebt -= repayAmount;
    }

    function liquidate(address user) external {
        _accrueInterest(user);
        require(getHealthFactor(user) < 1e18, "Position is healthy");
        
        Position storage pos = positions[user];
        uint256 debtToCover = pos.principalDebt;
        
        uint256 price = oracle.getPrice();
        uint256 collateralToSeize = ((debtToCover * 1e18) / price) * (100 + LIQUIDATION_BONUS) / 100;

        if (collateralToSeize > pos.collateral) {
            collateralToSeize = pos.collateral;
        }

        borrowToken.transferFrom(msg.sender, address(this), debtToCover);
        
        pos.principalDebt = 0;
        pos.collateral -= collateralToSeize;
        
        collateralToken.transfer(msg.sender, collateralToSeize);
    }
}