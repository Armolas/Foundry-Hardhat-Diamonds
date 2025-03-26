// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MockERC721 {
    mapping(uint256 => address) public ownerOf;
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    
    constructor() {
        ownerOf[1] = msg.sender;
    }
    
    function approve(address to, uint256 tokenId) external {
        require(ownerOf[tokenId] == msg.sender, "Not owner");
        _operatorApprovals[msg.sender][to] = true;
    }
    
    function getApproved(uint256 tokenId) external view returns (address) {
        require(ownerOf[tokenId] != address(0), "Token doesn't exist");
        // Simplified - returns the diamond address if approved
        return _operatorApprovals[ownerOf[tokenId]][address(this)] ? address(this) : address(0);
    }
    
    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    
    function transferFrom(address from, address to, uint256 tokenId) external returns (bool) {
        require(
            ownerOf[tokenId] == from &&
            (msg.sender == from || 
             _operatorApprovals[from][msg.sender]),
            "Transfer not authorized"
        );
        ownerOf[tokenId] = to;
        return true;
    }

    function setApprovalForAll(address operator, bool approved) external {
        _operatorApprovals[msg.sender][operator] = approved;
    }
}