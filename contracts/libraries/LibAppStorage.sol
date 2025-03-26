// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStake} from "../interfaces/IStake.sol";

library LibAppStorage {
    struct AppStorage {
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        mapping(address => IStake.Stake[]) stakes;
        mapping(address => uint256) stakeCount;
        uint256 baseAPR;
        uint256 decayRate;
        uint256 decayPeriod;
        address diamond;
        uint256 lastDecayUpdate;
        address erc20StakingToken;
        address erc721StakingToken;
        address erc1155StakingToken;
    }

    uint256 public constant SECONDS_IN_YEAR = 31536000;
    
    function appStorage() internal pure returns (AppStorage storage s) {
        bytes32 position = 0;
        assembly {
            s.slot := position
        }
    }
}