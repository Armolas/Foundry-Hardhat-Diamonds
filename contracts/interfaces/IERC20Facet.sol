// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Facet{
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint remaining);
    function balanceOf(address who) external view returns(uint256 balance);
    function transferFrom(address _from, address _to, uint256 _value) external returns(bool success);
    function transfer(address to, uint256 value) external returns(bool);
    function mint(address account, uint256 amount) external;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}