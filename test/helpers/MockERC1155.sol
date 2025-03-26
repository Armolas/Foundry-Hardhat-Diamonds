// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MockERC1155 {
    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    
    constructor() {
        balanceOf[msg.sender][1] = 100;
    }
    
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata) external returns (bool) {
        balanceOf[from][id] -= amount;
        balanceOf[to][id] += amount;
        return true;
    }
    
    function isApprovedForAll(address, address) external pure returns (bool) {
        return true;
    }
}