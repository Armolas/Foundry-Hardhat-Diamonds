// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStake{
    enum StakeType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct Stake {
        uint256 amount; // For ERC20 or number of ERC1155 tokens
        uint256 tokenId; // For ERC721/ERC1155 (0 for ERC20)
        address tokenAddress;
        uint256 stakedAt;
        bool claimed;
        StakeType stakeType;
    }

    function stake(
        StakeType stakeType,
        address tokenAddress,
        uint256 tokenId,
        uint256 amount
    ) external returns (uint256);

    function claim(uint256 stakeIndex) external returns (bool);
    function getTotalPendingRewards(address _user) external view returns (uint256 total);
    function getAllStakes(address _user) external view returns (Stake[] memory);
    function getStake(address _user, uint256 _stakeIndex)
    external 
    view 
    returns (
        uint256 amount,
        uint256 tokenId,
        address tokenAddress,
        uint256 stakedAt,
        bool claimed,
        StakeType stakeType
    );
    function calculateReward(address _user, uint256 _stakeIndex) external view returns (uint256);
    function initStake(uint256 _baseAPR, uint256 _decayRate, uint256 _decayPeriod, address _erc20StakingToken, address _erc721StakingToken, address _erc1155StakingToken)  external;
    function getCurrentAPR() external view returns (uint256);
    function updateDecay() external;
    function decayPeriod() external view returns (uint256);

    event Staked(
        address indexed staker,
        StakeType indexed stakeType,
        uint256 indexed amount,
        address tokenAddress,
        uint256 tokenId,
        uint256 stakeIndex
    );

    event Claimed(
        address indexed staker,
        StakeType indexed stakeType,
        uint256 indexed amount,
        address tokenAddress,
        uint256 tokenId,
        uint256 stakeIndex
    );
    event Deployed(address indexed erc20token, address indexed erc721token, address indexed erc1155token, uint256 apr);
    event StorageAddresses(address indexed erc20token, address indexed erc721token, address indexed erc1155token);

    event DecayUpdated(uint256 timestamp);
}