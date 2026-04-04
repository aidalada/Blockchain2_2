// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockOracle {
    uint256 public price; 

    constructor(uint256 _initialPrice) {
        price = _initialPrice;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function getPrice() external view returns (uint256) {
        return price;
    }
}