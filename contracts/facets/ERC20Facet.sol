// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Facet } from "../interfaces/IERC20Facet.sol";
import { LibAppStorage } from "../libraries/LibAppStorage.sol";

contract ERC20Facet is IERC20Facet {
    function initERC20(string memory _name, string memory _symbol, uint8 _decimals, uint256 _totalSupply) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.totalSupply == 0, "ALREADY_INITIALIZED");
        s.name = _name;
        s.symbol = _symbol;
        s.decimals = _decimals;
        s.totalSupply = _totalSupply;
        s.balances[address(this)] = _totalSupply;
    }

    function name() public view returns(string memory){
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.name;
    }

    function symbol() public view returns(string memory){
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.symbol;
    }

    function decimals() public view returns(uint8){
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.decimals;
    }

    function totalSupply() public view returns(uint256){
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.totalSupply;
    }

    function balanceOf(address _owner) public view returns(uint256){
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.balances[_owner];
    }

    function allowance(address _owner, address _spender) public view returns(uint256 remaining) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.allowances[_owner][_spender];
    }

    function transfer(address to, uint256 value) public returns(bool){
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.balances[msg.sender] >= value, 'Insufficient balance');
        s.balances[msg.sender] -= value;
        s.balances[to] += value;
        emit IERC20Facet.Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns(bool success) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.balances[_from] >= _value, 'Insufficient balance');
        require(s.allowances[_from][msg.sender] >= _value, 'Insufficient allowance');
        s.balances[_from] -= _value;
        s.balances[_to] += _value;
        s.allowances[_from][msg.sender] -= _value;
        emit IERC20Facet.Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns(bool success) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.allowances[msg.sender][_spender] = _value;
        emit IERC20Facet.Approval(msg.sender, _spender, _value);
        return true;
    }

    function mint(address _to, uint256 amount) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(msg.sender == s.diamond, "Must be diamond");
        s.totalSupply += amount;
        s.balances[_to] += amount;
    }
}