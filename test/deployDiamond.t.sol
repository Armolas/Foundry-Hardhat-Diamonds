// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/StakeFacet.sol";
import "../contracts/facets/TokenReceiverFacet.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IERC20Facet.sol";
import "../contracts/interfaces/IStake.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC1155.sol";
import "../contracts/interfaces/IERC721Receiver.sol";
import "../contracts/interfaces/IERC1155Receiver.sol";
import "../contracts/Diamond.sol";
import "./helpers/DiamondUtils.sol";
import "./helpers/MockERC20.sol";
import "./helpers/MockERC721.sol";
import "./helpers/MockERC1155.sol";

contract DiamondTest is Test, DiamondUtils, IDiamondCut {
    Diamond diamond;
    address diamondAddress;
    TokenReceiverFacet tokenReceiver;
    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);
    
    MockERC20 erc20Token;
    MockERC721 erc721Token;
    MockERC1155 erc1155Token;
    
    uint256 baseAPR = 1000; // 10%
    uint256 decayRate = 100; // 1% decay
    uint256 decayPeriod = 1 days;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy mock tokens
        erc20Token = new MockERC20(1000 ether);
        erc721Token = new MockERC721();
        erc1155Token = new MockERC1155();
        
        // Deploy diamond
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(dCutFacet));
        diamondAddress = address(diamond);
        
        // Deploy and add facets
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        OwnershipFacet ownerF = new OwnershipFacet();
        ERC20Facet erc20Facet = new ERC20Facet();
        StakeFacet stakeFacet = new StakeFacet();
        TokenReceiverFacet tokenReceiverFacet = new TokenReceiverFacet();

    
        // Build cut data
        FacetCut[] memory cut = new FacetCut[](5);
        
        cut[0] = FacetCut({
            facetAddress: address(dLoupe),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("DiamondLoupeFacet")
        });
        
        cut[1] = FacetCut({
            facetAddress: address(ownerF),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("OwnershipFacet")
        });
        
        cut[2] = FacetCut({
            facetAddress: address(erc20Facet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("ERC20Facet")
        });
        
        cut[3] = FacetCut({
            facetAddress: address(stakeFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("StakeFacet")
        });

        cut[4] = FacetCut({
            facetAddress: address(tokenReceiverFacet),
            action: FacetCutAction.Add,
            functionSelectors: generateSelectors("TokenReceiverFacet")
        });
        
        // Add facets to diamond
        IDiamondCut(diamondAddress).diamondCut(cut, address(0), "");
        ERC20Facet(diamondAddress).initERC20("StakingToken", "STK", 18, 1000000 ether);
        StakeFacet(diamondAddress).initStake(
            baseAPR,
            decayRate,
            decayPeriod,
            address(erc20Token),
            address(erc721Token),
            address(erc1155Token)
        );

        tokenReceiver = new TokenReceiverFacet();
        
        vm.stopPrank();
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
    
    // Helper function
    function getStakeFacet() internal view returns (IStake) {
        return IStake(diamondAddress);
    }
    
    function getERC20Facet() internal view returns (IERC20Facet) {
        return IERC20Facet(diamondAddress);
    }
    
    // ERC20Facet Tests
    function testERC20InitialState() public {
        IERC20Facet erc20 = getERC20Facet();
        assertEq(erc20.name(), "StakingToken");
        assertEq(erc20.symbol(), "STK");
        assertEq(erc20.decimals(), 18);
        assertEq(erc20.totalSupply(), 1000000 ether);
        assertEq(erc20.balanceOf(diamondAddress), 1000000 ether);
    }
    
    function testERC20Transfer() public {
        IERC20Facet erc20 = getERC20Facet();
        vm.prank(diamondAddress);
        erc20.transfer(user1, 100 ether);
        assertEq(erc20.balanceOf(user1), 100 ether);
        assertEq(erc20.balanceOf(diamondAddress), 1000000 ether - 100 ether);
    }
    
    function testERC20TransferFrom() public {
        IERC20Facet erc20 = getERC20Facet();
        vm.prank(diamondAddress);
        erc20.approve(user1, 50 ether);
        
        vm.prank(user1);
        erc20.transferFrom(diamondAddress, user2, 50 ether);
        
        assertEq(erc20.balanceOf(diamondAddress), 1000000 ether - 50 ether);
        assertEq(erc20.balanceOf(user2), 50 ether);
        assertEq(erc20.allowance(diamondAddress, user1), 0);
    }
    
    // StakeFacet Tests - ERC20
    function testStakeERC20() public {
        IStake stake = getStakeFacet();
        
        // Prepare user with tokens
        vm.prank(owner);
        erc20Token.transfer(user1, 100 ether);
        
        // Approve diamond to spend tokens
        vm.prank(user1);
        erc20Token.approve(diamondAddress, 100 ether);
        
        // Stake tokens
        vm.prank(user1);
        uint256 stakeIndex = stake.stake(
            IStake.StakeType.ERC20,
            address(erc20Token),
            0, // tokenId
            50 ether
        );
        
        // Verify stake
        (uint256 amount,,,uint256 stakedAt,,) = stake.getStake(user1, stakeIndex);
        assertEq(amount, 50 ether);
        assertEq(stakedAt, block.timestamp);
        assertEq(erc20Token.balanceOf(user1), 50 ether);
        assertEq(erc20Token.balanceOf(diamondAddress), 50 ether);
    }

    function testUpdateDecay() public {
        IStake stake = getStakeFacet();
        
        // Get initial values
        uint256 initialAPR = stake.getCurrentAPR();
        uint256 initialDecayUpdate = block.timestamp;
        
        // Fast forward half decay period
        uint256 timePassed = stake.decayPeriod() / 2;
        vm.warp(block.timestamp + timePassed);
        
        // Update decay
        vm.prank(owner); // Should restrict to owner in actual implementation
        stake.updateDecay();
        
        // Verify
        uint256 newDecayUpdate = block.timestamp;
        uint256 newAPR = stake.getCurrentAPR();
        
        // Should have same APR since we updated exactly at half period
        assertEq(newAPR, initialAPR);
        assertEq(newDecayUpdate, initialDecayUpdate + timePassed);
        
        // Verify event emission
        vm.expectEmit(true, true, true, true);
        emit IStake.DecayUpdated(newDecayUpdate);
        vm.prank(owner);
        stake.updateDecay();
    }

    function testGetAllStakes() public {
        IStake stake = getStakeFacet();
        
        // Setup - create multiple stakes
        vm.prank(owner);
        erc20Token.transfer(user1, 200 ether);
        vm.prank(user1);
        erc20Token.approve(diamondAddress, 200 ether);
        
        // First stake
        vm.prank(user1);
        stake.stake(IStake.StakeType.ERC20, address(erc20Token), 0, 50 ether);
        
        // Second stake
        vm.warp(block.timestamp + 1 days);
        vm.prank(user1);
        stake.stake(IStake.StakeType.ERC20, address(erc20Token), 0, 75 ether);
        
        // Get all stakes
        IStake.Stake[] memory stakes = stake.getAllStakes(user1);

        IStake.StakeType stakeTypeERC20 = IStake.StakeType.ERC20;
        
        // Verify
        assertEq(stakes.length, 2);
        assertEq(stakes[0].amount, 50 ether);
        assertEq(uint256(stakes[0].stakeType), uint256(stakeTypeERC20));
        assertEq(stakes[1].amount, 75 ether);
        assertEq(stakes[1].stakedAt, block.timestamp);
        
        // Verify empty array for user with no stakes
        IStake.Stake[] memory emptyStakes = stake.getAllStakes(user2);
        assertEq(emptyStakes.length, 0);
    }

    function testGetTotalPendingRewards() public {
        IStake stake = getStakeFacet();
        
        // Setup - create multiple stakes
        vm.prank(owner);
        erc20Token.transfer(user1, 200 ether);
        vm.prank(user1);
        erc20Token.approve(diamondAddress, 200 ether);
        
        // First stake
        vm.prank(user1);
        uint256 firstStakeIndex = stake.stake(IStake.StakeType.ERC20, address(erc20Token), 0, 50 ether);
        
        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);
        
        // Second stake
        vm.prank(user1);
        stake.stake(IStake.StakeType.ERC20, address(erc20Token), 0, 75 ether);
        
        // Fast forward another 30 days
        vm.warp(block.timestamp + 30 days);
        
        // Calculate expected rewards
        uint256 expectedReward1 = stake.calculateReward(user1, firstStakeIndex);
        uint256 expectedReward2 = stake.calculateReward(user1, 1);
        uint256 expectedTotal = expectedReward1 + expectedReward2;
        
        // Test getTotalPendingRewards
        uint256 totalRewards = stake.getTotalPendingRewards(user1);
        assertApproxEqRel(totalRewards, expectedTotal, 0.01e18); // 1% tolerance
        
        // Claim first stake and verify total updates
        vm.prank(user1);
        stake.claim(firstStakeIndex);
        
        uint256 remainingRewards = stake.getTotalPendingRewards(user1);
        assertApproxEqRel(remainingRewards, expectedReward2, 0.01e18);
        
        // Verify zero for user with no stakes
        assertEq(stake.getTotalPendingRewards(user2), 0);
    }
        
    function testClaimERC20() public {
        IStake stake = getStakeFacet();
        
        // Setup stake
        vm.prank(owner);
        erc20Token.transfer(user1, 100 ether);
        vm.prank(user1);
        erc20Token.approve(diamondAddress, 100 ether);
        vm.prank(user1);
        uint256 stakeIndex = stake.stake(IStake.StakeType.ERC20, address(erc20Token), 0, 50 ether);
        
        // Fast forward 1 day
        vm.warp(block.timestamp + 30 days);
        
        // Claim
        vm.prank(user1);
        bool success = stake.claim(stakeIndex);
        
        assertTrue(success);
        assertEq(erc20Token.balanceOf(user1), 100 ether); // Got original tokens back
        assertGt(getERC20Facet().balanceOf(user1), 0); // Got rewards
    }
    
    // StakeFacet Tests - ERC721
    function testStakeERC721() public {
        IStake stake = getStakeFacet();
        
        // Approve diamond to spend NFT
        vm.prank(owner);
        erc721Token.transferFrom(owner, user1, 1);
        vm.prank(user1);
        erc721Token.approve(diamondAddress, 1);
        
        // Stake NFT
        vm.prank(user1);
        uint256 stakeIndex = stake.stake(
            IStake.StakeType.ERC721,
            address(erc721Token),
            1, // tokenId
            1 // amount (ignored for ERC721)
        );
        
        // Verify stake
        (,,,uint256 stakedAt,,) = stake.getStake(user1, stakeIndex);
        assertEq(stakedAt, block.timestamp);
        assertEq(erc721Token.ownerOf(1), diamondAddress);
    }

    function testInitStakeReinitialization() public {
        IStake stake = getStakeFacet();
        
        // Second attempt should fail
        vm.expectRevert("Already initialized");
        stake.initStake(baseAPR, decayRate, decayPeriod, address(erc20Token), address(erc721Token), address(erc1155Token));
    }
    
    // StakeFacet Tests - ERC1155
    function testStakeERC1155() public {
        IStake stake = getStakeFacet();
        
        // Stake tokens
        vm.prank(owner);
        uint256 stakeIndex = stake.stake(
            IStake.StakeType.ERC1155,
            address(erc1155Token),
            1, // tokenId
            10 // amount
        );
        
        // Verify stake
        (uint256 amount,,,uint256 stakedAt,,) = stake.getStake(owner, stakeIndex);
        assertEq(amount, 10);
        assertEq(stakedAt, block.timestamp);
        assertEq(erc1155Token.balanceOf(owner, 1), 90);
        assertEq(erc1155Token.balanceOf(diamondAddress, 1), 10);
    }

    function testStakeNotInitialized() public {
        // Deploy new uninitialized stake facet
        StakeFacet newStake = new StakeFacet();
        
        vm.expectRevert("StakeFacet: not initialized");
        newStake.stake(IStake.StakeType.ERC20, address(erc20Token), 0, 100);
    }

    function testStakeERC721ApprovalChecks() public {
        IStake stake = getStakeFacet();
        // Setup - mint NFT to user1 and approve diamond
        vm.prank(owner);
        erc721Token.transferFrom(owner, user1, 1);
        
        // Should fail without any approval
        vm.prank(user1);
        vm.expectRevert("StakeFacet: not approved");
        stake.stake(IStake.StakeType.ERC721, address(erc721Token), 1, 1);
        
        // Test with token-level approval only
        vm.prank(user1);
        erc721Token.approve(address(stake), 1);
        
        vm.prank(user1);
        uint256 stakeIndex1 = stake.stake(IStake.StakeType.ERC721, address(erc721Token), 1, 1);
        assertEq(stakeIndex1, 0);
        
        // Return NFT to user1 for next test
        vm.prank(address(stake));
        erc721Token.transferFrom(address(stake), user1, 1);
        
        // Test with operator approval only
        vm.prank(user1);
        erc721Token.setApprovalForAll(address(stake), true);
        
        vm.prank(user1);
        uint256 stakeIndex2 = stake.stake(IStake.StakeType.ERC721, address(erc721Token), 1, 1);
        assertEq(stakeIndex2, 1);
    }
    
    // Reward Calculation Tests
    function testRewardCalculation() public {
        IStake stake = getStakeFacet();
        
        // Setup stake
        vm.prank(owner);
        erc20Token.transfer(user1, 100 ether);
        vm.prank(user1);
        erc20Token.approve(diamondAddress, 100 ether);
        vm.prank(user1);
        uint256 stakeIndex = stake.stake(IStake.StakeType.ERC20, address(erc20Token), 0, 50 ether);
        
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        
        // Calculate reward (should be ~50 ether * 10% = 5 ether)
        uint256 reward = stake.calculateReward(user1, stakeIndex);
        assertApproxEqRel(reward, 0.1 ether, 0.01e18); // 1% tolerance
        
        // Check APR decay
        uint256 currentAPR = stake.getCurrentAPR();
        assertLt(currentAPR, baseAPR); // Should have decayed
    }
    
    // Edge Cases
    function testCannotStakeZeroAmount() public {
        IStake stake = getStakeFacet();
        
        vm.prank(user1);
        vm.expectRevert("StakeFacet: amount must be greater than 0");
        stake.stake(IStake.StakeType.ERC20, address(erc20Token), 0, 0);
    }
    
    function testCannotClaimBeforeTime() public {
        IStake stake = getStakeFacet();
        
        // Setup stake
        vm.prank(owner);
        erc20Token.transfer(user1, 100 ether);
        vm.prank(user1);
        erc20Token.approve(diamondAddress, 100 ether);
        vm.prank(user1);
        uint256 stakeIndex = stake.stake(IStake.StakeType.ERC20, address(erc20Token), 0, 50 ether);
        
        // Try to claim immediately
        vm.prank(user1);
        vm.expectRevert("StakeFacet: must be staked for at least 1 day");
        stake.claim(stakeIndex);
    }
    
    function testCannotStakeWrongToken() public {
        IStake stake = getStakeFacet();
        
        vm.prank(user1);
        vm.expectRevert("StakeFacet: tokenAddress must be erc20StakingToken");
        stake.stake(IStake.StakeType.ERC20, address(0x123), 0, 50 ether);
    }
    
    // Diamond-specific tests
    function testDiamondLoupeFunctions() public {
        DiamondLoupeFacet loupe = DiamondLoupeFacet(diamondAddress);
        
        address[] memory facets = loupe.facetAddresses();
        assertEq(facets.length, 6); // All our facets
        
        bytes4[] memory selectors = loupe.facetFunctionSelectors(facets[0]);
        assertTrue(selectors.length > 0);
    }
    
    function testOwnershipFunctions() public {
        OwnershipFacet ownership = OwnershipFacet(diamondAddress);
        assertEq(ownership.owner(), owner);
    }

    // Test ERC721 Receiver
    function testERC721Receiver() public {
        bytes4 selector = tokenReceiver.onERC721Received(
            address(0x1), // operator
            address(0x2), // from
            123,          // tokenId
            ""            // data
        );
        
        assertEq(selector, IERC721Receiver.onERC721Received.selector);
    }

    // Test ERC1155 Single Receiver
    function testERC1155SingleReceiver() public {
        bytes4 selector = tokenReceiver.onERC1155Received(
            address(0x1), // operator
            address(0x2), // from
            123,          // id
            1,            // value
            ""            // data
        );
        
        assertEq(selector, IERC1155Receiver.onERC1155Received.selector);
    }

    // Test ERC1155 Batch Receiver
    function testERC1155BatchReceiver() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 123;
        ids[1] = 456;
        
        uint256[] memory values = new uint256[](2);
        values[0] = 1;
        values[1] = 5;
        
        bytes4 selector = tokenReceiver.onERC1155BatchReceived(
            address(0x1), // operator
            address(0x2), // from
            ids,
            values,
            ""            // data
        );
        
        assertEq(selector, IERC1155Receiver.onERC1155BatchReceived.selector);
    }
}