// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Facet } from "../interfaces/IERC20Facet.sol";
import { LibAppStorage } from "../libraries/LibAppStorage.sol";
import { IStake } from "../interfaces/IStake.sol";
import { IERC721 } from "../interfaces/IERC721.sol";
import { IERC1155 } from "../interfaces/IERC1155.sol";

contract StakeFacet is IStake{
    function initStake(uint256 _baseAPR, uint256 _decayRate, uint256 _decayPeriod, address _erc20StakingToken, address _erc721StakingToken, address _erc1155StakingToken)  external{
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.diamond == address(0), "Already initialized");
        s.diamond = address(this);
        s.baseAPR = _baseAPR;
        s.decayRate = _decayRate;
        s.decayPeriod = _decayPeriod;
        s.erc20StakingToken = _erc20StakingToken;
        s.erc721StakingToken = _erc721StakingToken;
        s.erc1155StakingToken = _erc1155StakingToken;
        s.lastDecayUpdate = block.timestamp;
        emit IStake.Deployed(s.erc20StakingToken, s.erc721StakingToken, s.erc1155StakingToken, _baseAPR);
    }

    function stake(IStake.StakeType stakeType, address tokenAddress, uint256 tokenId, uint256 amount) external returns (uint256){
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.diamond != address(0), "StakeFacet: not initialized");
        emit IStake.StorageAddresses(s.erc20StakingToken, s.erc721StakingToken, s.erc1155StakingToken);
        require(amount > 0, "StakeFacet: amount must be greater than 0");
        require(tokenAddress != address(0), "StakeFacet: tokenAddress must be non-zero");
        require(stakeType == IStake.StakeType.ERC20 || stakeType == IStake.StakeType.ERC721 || stakeType == IStake.StakeType.ERC1155, "StakeFacet: stakeType must be valid");
        if(stakeType == IStake.StakeType.ERC20){
            require(tokenAddress == s.erc20StakingToken, "StakeFacet: tokenAddress must be erc20StakingToken");
            require(tokenId == 0, "StakeFacet: tokenId must be 0 for ERC20");
            require(IERC20Facet(tokenAddress).transferFrom(msg.sender, address(this), amount), "StakeFacet: transferFrom failed");
        } else if(stakeType == IStake.StakeType.ERC721){
            require(tokenAddress == s.erc721StakingToken, "StakeFacet: tokenAddress must be erc721StakingToken");
            require(IERC721(tokenAddress).ownerOf(tokenId) == msg.sender, "StakeFacet: not owner of tokenId");
            address approved = IERC721(tokenAddress).getApproved(tokenId);
            bool isApprovedForAll = IERC721(tokenAddress).isApprovedForAll(msg.sender, address(this));
            require(approved == address(this) || isApprovedForAll, "StakeFacet: not approved");
            require(IERC721(tokenAddress).transferFrom(msg.sender, address(this), tokenId), "StakeFacet: transferFrom failed");
        } else if(stakeType == IStake.StakeType.ERC1155){
            require(tokenAddress == s.erc1155StakingToken, "StakeFacet: tokenAddress must be erc1155StakingToken");
            require(IERC1155(tokenAddress).balanceOf(msg.sender, tokenId) >= amount, "StakeFacet: insufficient balance");
            require(IERC1155(tokenAddress).isApprovedForAll(msg.sender, address(this)), "StakeFacet: not approved for all");
            require(IERC1155(tokenAddress).safeTransferFrom(msg.sender, address(this), tokenId, amount, ""), "StakeFacet: safeTransferFrom failed");
        }
        IStake.Stake memory newStake = IStake.Stake({
            amount: amount,
            tokenId: tokenId,
            tokenAddress: tokenAddress,
            stakedAt: block.timestamp,
            claimed: false,
            stakeType: stakeType
        });
        s.stakes[msg.sender].push(newStake);
        s.stakeCount[msg.sender]++;
        emit IStake.Staked(msg.sender, stakeType, amount, tokenAddress, tokenId, s.stakeCount[msg.sender]);
        return s.stakeCount[msg.sender] - 1;
    }

    function claim(uint256 stakeIndex) external returns (bool){
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.stakes[msg.sender].length > stakeIndex, "StakeFacet: invalid stake index");
        IStake.Stake storage userStake = s.stakes[msg.sender][stakeIndex];
        require(userStake.stakedAt > 0, "StakeFacet: stakeIndex does not exist");
        require(!userStake.claimed, "StakeFacet: already claimed");
        require(block.timestamp - userStake.stakedAt >= 1 days, "StakeFacet: must be staked for at least 1 day");
        uint256 reward = calculateReward(msg.sender, stakeIndex);   
        userStake.claimed = true;
        IERC20Facet(s.diamond).mint(msg.sender, reward);
        if (userStake.stakeType == IStake.StakeType.ERC20){
            IERC20Facet(userStake.tokenAddress).transfer(msg.sender, userStake.amount);
        } else if (userStake.stakeType == IStake.StakeType.ERC721) {
            IERC721(userStake.tokenAddress).safeTransferFrom(address(this), msg.sender, userStake.tokenId);
        } else {
            IERC1155(userStake.tokenAddress).safeTransferFrom(
            address(this),
            msg.sender,
            userStake.tokenId,
            userStake.amount,
            ""
        );
        }
        emit IStake.Claimed(msg.sender, userStake.stakeType, userStake.amount, userStake.tokenAddress, userStake.tokenId, stakeIndex);
        return true;
    }

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
    ) 
    {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(_stakeIndex < s.stakes[_user].length, "StakeFacet: invalid stake index");
        
        IStake.Stake memory stakeInfo = s.stakes[_user][_stakeIndex];
        return (
            stakeInfo.amount,
            stakeInfo.tokenId,
            stakeInfo.tokenAddress,
            stakeInfo.stakedAt,
            stakeInfo.claimed,
            stakeInfo.stakeType
        );
    }

    function getAllStakes(address _user) external view returns (Stake[] memory) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.stakes[_user];
    }

    function getTotalPendingRewards(address _user) external view returns (uint256 total) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        for (uint256 i = 0; i < s.stakes[_user].length; i++) {
            if (!s.stakes[_user][i].claimed) {
                total += calculateReward(_user, i);
            }
        }
    }

    // Updated reward calculation functions with safe math
    function calculateReward(address _user, uint256 _stakeIndex) public view returns (uint256) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        Stake storage userStake = s.stakes[_user][_stakeIndex];
        

        uint256 timeStaked = block.timestamp - userStake.stakedAt;
        
        // Calculate current APR with decay (updated to prevent overflow)
        uint256 currentAPR = getCurrentAPR();
        
        // Calculate reward based on stake type
        uint256 stakeValue;
        if (userStake.stakeType == IStake.StakeType.ERC20) { // ERC20
            stakeValue = userStake.amount;
        } else if (userStake.stakeType == IStake.StakeType.ERC721) { // ERC721
            stakeValue = 1 * 10**18; // Assuming 1 NFT = 1 token worth
        } else { // ERC1155
            stakeValue = userStake.amount * 10**18; // Assuming 1 ERC1155 = 1 token worth
        }
        
        // Safe reward calculation (multiply before divide)
        uint256 reward = stakeValue * currentAPR;
        reward = reward * timeStaked;
        reward = reward / (365 days * 10000);
        
        return reward;
    }

    // Updated APR decay calculation to prevent overflow
    function getCurrentAPR() public view returns (uint256) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        if (block.timestamp <= s.lastDecayUpdate) return s.baseAPR;
        
        uint256 periodsPassed = (block.timestamp - s.lastDecayUpdate) / s.decayPeriod;
        if (periodsPassed == 0) return s.baseAPR;
        
        // Safe decay calculation using exponentiation by squaring
        uint256 decayFactor = 10000;
        for (uint256 i = 0; i < periodsPassed; i++) {
            decayFactor = decayFactor * (10000 - s.decayRate) / 10000;
            if (decayFactor == 0) break; // Prevent division by zero
        }
        
        return s.baseAPR * decayFactor / 10000;
    }

    function updateDecay() external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.lastDecayUpdate = block.timestamp;
        emit IStake.DecayUpdated(block.timestamp);
    }

    function decayPeriod() external view returns (uint256) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.decayPeriod;
    }
}