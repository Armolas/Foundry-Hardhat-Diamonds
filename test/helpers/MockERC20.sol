// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MockERC20 {
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowance;
    
    constructor(uint256 initialSupply) {
        balances[msg.sender] = initialSupply;
    }

    function balanceOf(address owner) external view returns (uint256) {
        return balances[owner];
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}