// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract LPToken {
    string public name = "AMM Liquidity Provider Token";
    string public symbol = "AMM-LP";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address public amm;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        amm = msg.sender; 
    }

    modifier onlyAMM() {
        require(msg.sender == amm, "Only AMM can call this");
        _;
    }

    function mint(address to, uint256 amount) external onlyAMM {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external onlyAMM {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
}