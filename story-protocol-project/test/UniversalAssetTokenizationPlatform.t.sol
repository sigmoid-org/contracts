// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";

import { UniversalAssetTokenizationPlatform } from "../src/UniversalAssetTokenisationPlatform.sol";
import { AssetNFT } from "../src/AssetNFT.sol";
import { AssetShareToken } from "../src/AssetShareToken.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/UniversalAssetTokenizationPlatformTest.t.sol

contract UniversalAssetTokenizationPlatformTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);
    address internal charlie = address(0xc4a12e);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    address internal ipAssetRegistry = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
    address internal licenseRegistry = 0x529a750E02d8E2f15649c13D69a465286a780e24;
    address internal licensingModule = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
    address internal pilTemplate = 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316;
    address internal royaltyPolicyLAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    address internal wip = 0x1514000000000000000000000000000000000000;

    UniversalAssetTokenizationPlatform public platform;
    AssetNFT public assetNFT;

    function setUp() public {
        // Mock IPGraph for testing
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        platform = new UniversalAssetTokenizationPlatform(
            ipAssetRegistry,
            licensingModule,
            pilTemplate,
            royaltyPolicyLAP,
            wip
        );
        
        assetNFT = platform.ASSET_NFT();
        
        // Give test accounts some ETH
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }

    function test_createAsset_Success() public {
        vm.startPrank(alice);
        
        uint256 assetId = platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.MUSIC,
            "My First Song",
            "A beautiful melody",
            "ipfs://metadata-hash",
            5000, // 50% creator shares
            0.01 ether, // Price per share
            25 // 25% commercial revenue share
        );
        
        vm.stopPrank();
        
        // Verify asset was created correctly
        UniversalAssetTokenizationPlatform.Asset memory asset = platform.getAsset(assetId);
        
        assertEq(uint256(asset.assetType), uint256(UniversalAssetTokenizationPlatform.AssetType.MUSIC));
        assertEq(asset.title, "My First Song");
        assertEq(asset.description, "A beautiful melody");
        assertEq(asset.metadataURI, "ipfs://metadata-hash");
        assertEq(asset.creator, alice);
        assertTrue(asset.exists);
        assertEq(uint256(asset.verificationStatus), uint256(UniversalAssetTokenizationPlatform.VerificationStatus.PENDING));
        
        // Verify NFT was minted and transferred to creator
        assertEq(assetNFT.ownerOf(asset.nftTokenId), alice);
        
        // Verify IP Asset registration
        IIPAssetRegistry ipRegistry = IIPAssetRegistry(ipAssetRegistry);
        assertTrue(ipRegistry.isRegistered(asset.ipId));
        
        // Verify license terms attachment
        ILicenseRegistry LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        assertTrue(LICENSE_REGISTRY.hasIpAttachedLicenseTerms(asset.ipId, pilTemplate, asset.licenseTermsId));
        
        // Verify share token creation and allocation
        AssetShareToken shareToken = AssetShareToken(asset.shareTokenAddress);
        assertEq(shareToken.ASSET_ID(), assetId);
        assertEq(shareToken.totalSupply(), 5000); // Creator's shares minted
        assertEq(shareToken.balanceOf(alice), 5000); // Creator owns their shares
        
        (uint256 creatorShares, uint256 publicShares, uint256 pricePerShare, bool saleActive) = shareToken.allocation();
        assertEq(creatorShares, 5000);
        assertEq(publicShares, 5000); // Remaining for public
        assertEq(pricePerShare, 0.01 ether);
        assertTrue(saleActive);
    }

    function test_createAsset_MultipleAssetTypes() public {
        UniversalAssetTokenizationPlatform.AssetType[8] memory assetTypes = [
            UniversalAssetTokenizationPlatform.AssetType.MUSIC,
            UniversalAssetTokenizationPlatform.AssetType.POETRY,
            UniversalAssetTokenizationPlatform.AssetType.DANCE,
            UniversalAssetTokenizationPlatform.AssetType.ART,
            UniversalAssetTokenizationPlatform.AssetType.VIDEO,
            UniversalAssetTokenizationPlatform.AssetType.WRITING,
            UniversalAssetTokenizationPlatform.AssetType.CODE,
            UniversalAssetTokenizationPlatform.AssetType.OTHER
        ];
        
        string[8] memory titles = [
            "Song Title",
            "Poem Title", 
            "Dance Title",
            "Art Title",
            "Video Title",
            "Writing Title",
            "Code Title",
            "Other Title"
        ];
        
        vm.startPrank(alice);
        
        for (uint256 i = 0; i < assetTypes.length; i++) {
            uint256 assetId = platform.createAsset(
                assetTypes[i],
                titles[i],
                "Description",
                "ipfs://metadata",
                3000, // 30% creator shares
                0.005 ether,
                10 // 10% commercial revenue share
            );
            
            UniversalAssetTokenizationPlatform.Asset memory asset = platform.getAsset(assetId);
            assertEq(uint256(asset.assetType), uint256(assetTypes[i]));
            assertEq(asset.title, titles[i]);
        }
        
        vm.stopPrank();
        
        // Verify creator profile updated - only non-array/mapping fields are returned
        // CreatorProfile: wallet, assetsCreated, isVerified, verificationStatus
        (address wallet, uint256 assetsCreated, bool isVerified, UniversalAssetTokenizationPlatform.VerificationStatus verificationStatus,string memory profilephotoIPFS ,string memory bio, string memory platformName) = platform.creators(alice);
        assertEq(wallet, alice);
        assertEq(assetsCreated, 8);
        assertFalse(isVerified); // Not verified by default
        assertEq(uint256(verificationStatus), uint256(UniversalAssetTokenizationPlatform.VerificationStatus.PENDING));
    }

    function test_createAsset_BoundaryValues() public {
        vm.startPrank(alice);
        
        // Test minimum creator shares (10%)
        uint256 assetId1 = platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.ART,
            "Min Creator Shares",
            "Testing minimum",
            "ipfs://min",
            1000, // 10% - minimum allowed
            0.001 ether,
            1 // 1% commercial revenue share
        );
        
        UniversalAssetTokenizationPlatform.Asset memory asset1 = platform.getAsset(assetId1);
        AssetShareToken shareToken1 = AssetShareToken(asset1.shareTokenAddress);
        assertEq(shareToken1.balanceOf(alice), 1000); // 10% of 10000 total shares
        
        // Test maximum creator shares (90%)
        uint256 assetId2 = platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.VIDEO,
            "Max Creator Shares", 
            "Testing maximum",
            "ipfs://max",
            9000, // 90% - maximum allowed
            1 ether,
            100 // 100% commercial revenue share - maximum
        );
        
        UniversalAssetTokenizationPlatform.Asset memory asset2 = platform.getAsset(assetId2);
        AssetShareToken shareToken2 = AssetShareToken(asset2.shareTokenAddress);
        assertEq(shareToken2.balanceOf(alice), 9000); // 90% of 10000 total shares
        (uint256 creatorShares, uint256 publicShares, , ) = shareToken2.allocation();
        assertEq(creatorShares, 9000);
        assertEq(publicShares, 1000); // Only 10% for public
        
        vm.stopPrank();
    }

    function test_createAsset_RevertConditions() public {
        vm.startPrank(alice);
        
        // Test creator shares too high (> 90%)
        vm.expectRevert("Creator cannot own more than 90%");
        platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.MUSIC,
            "Too High Shares",
            "Description",
            "ipfs://metadata",
            9500, // 95% - too high
            0.01 ether,
            50
        );
        
        // Test creator shares too low (< 10%)
        vm.expectRevert("Creator must own at least 10%");
        platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.MUSIC,
            "Too Low Shares", 
            "Description",
            "ipfs://metadata",
            500, // 5% - too low
            0.01 ether,
            50
        );
        
        // Test commercial revenue share too high (> 100%)
        vm.expectRevert("Commercial rev share cannot exceed 100%");
        platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.MUSIC,
            "High Rev Share",
            "Description", 
            "ipfs://metadata",
            5000, // 50%
            0.01 ether,
            150 // 150% - too high
        );
        
        vm.stopPrank();
    }

    function test_createAsset_Events() public {
        vm.startPrank(alice);
        
        // Expect AssetCreated event
        vm.expectEmit(true, true, false, true);
        emit UniversalAssetTokenizationPlatform.AssetCreated(
            0, // First asset ID
            alice,
            UniversalAssetTokenizationPlatform.AssetType.POETRY,
            "Beautiful Poem"
        );
        
        platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.POETRY,
            "Beautiful Poem",
            "A touching piece",
            "ipfs://poem-metadata",
            4000, // 40% creator shares
            0.02 ether,
            15 // 15% commercial revenue share
        );
        
        vm.stopPrank();
    }

    function test_createAsset_MultipleCreators() public {
        // Alice creates an asset
        vm.startPrank(alice);
        uint256 aliceAssetId = platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.MUSIC,
            "Alice's Song",
            "Alice's creation",
            "ipfs://alice",
            6000, // 60%
            0.01 ether,
            20
        );
        vm.stopPrank();
        
        // Bob creates an asset
        vm.startPrank(bob);
        uint256 bobAssetId = platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.ART,
            "Bob's Art",
            "Bob's masterpiece", 
            "ipfs://bob",
            7000, // 70%
            0.05 ether,
            30
        );
        vm.stopPrank();
        
        // Verify both assets exist and have correct creators
        UniversalAssetTokenizationPlatform.Asset memory aliceAsset = platform.getAsset(aliceAssetId);
        UniversalAssetTokenizationPlatform.Asset memory bobAsset = platform.getAsset(bobAssetId);
        
        assertEq(aliceAsset.creator, alice);
        assertEq(bobAsset.creator, bob);
        assertEq(aliceAsset.title, "Alice's Song");
        assertEq(bobAsset.title, "Bob's Art");
        
        // Verify creator profiles
        (, uint256 aliceAssetsCreated, , , , , ) = platform.creators(alice);
        (, uint256 bobAssetsCreated, , , , , ) = platform.creators(bob);
        assertEq(aliceAssetsCreated, 1);
        assertEq(bobAssetsCreated, 1);
        
        // Verify NFT ownership
        assertEq(assetNFT.ownerOf(aliceAsset.nftTokenId), alice);
        assertEq(assetNFT.ownerOf(bobAsset.nftTokenId), bob);
    }

    function test_createAsset_ShareTokenProperties() public {
        vm.startPrank(alice);
        
        uint256 assetId = platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.CODE,
            "Smart Contract Code",
            "Revolutionary DeFi protocol",
            "ipfs://code-metadata",
            3500, // 35% creator shares
            0.1 ether, // High price per share
            75 // 75% commercial revenue share
        );
        
        vm.stopPrank();
        
        UniversalAssetTokenizationPlatform.Asset memory asset = platform.getAsset(assetId);
        AssetShareToken shareToken = AssetShareToken(asset.shareTokenAddress);
        
        // Verify share token properties
        assertEq(shareToken.name(), "Smart Contract Code Shares");
        assertEq(shareToken.symbol(), "$CODE");
        assertEq(shareToken.owner(), alice);
        assertEq(shareToken.PLATFORM(), address(platform));
        assertEq(shareToken.ASSET_ID(), assetId);
        assertEq(shareToken.TOTAL_SHARES(), 10000);
        
        // Verify allocation
        (uint256 creatorShares, uint256 publicShares, uint256 pricePerShare, bool saleActive) = shareToken.allocation();
        assertEq(creatorShares, 3500);
        assertEq(publicShares, 6500);
        assertEq(pricePerShare, 0.1 ether);
        assertTrue(saleActive);
        
        // Verify creator balance
        assertEq(shareToken.balanceOf(alice), 3500);
        assertEq(shareToken.totalSupply(), 3500); // Only creator shares minted initially
    }

    function test_getCreatorAssets() public {
        vm.startPrank(alice);
        
        // Create multiple assets
        uint256 assetId1 = platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.MUSIC,
            "Song 1", "Desc 1", "ipfs://1", 5000, 0.01 ether, 25
        );
        
        uint256 assetId2 = platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.ART,
            "Art 1", "Desc 2", "ipfs://2", 6000, 0.02 ether, 30
        );
        
        uint256 assetId3 = platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.VIDEO,
            "Video 1", "Desc 3", "ipfs://3", 4000, 0.03 ether, 20
        );
        
        vm.stopPrank();
        
        // Get Alice's assets
        uint256[] memory aliceAssets = platform.getCreatorAssets(alice);
        
        assertEq(aliceAssets.length, 3);
        assertEq(aliceAssets[0], assetId1);
        assertEq(aliceAssets[1], assetId2);
        assertEq(aliceAssets[2], assetId3);
        
        // Create asset with different creator
        vm.startPrank(bob);
        platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.POETRY,
            "Poem 1", "Desc 4", "ipfs://4", 7000, 0.01 ether, 15
        );
        vm.stopPrank();
        
        // Verify Alice still has only 3 assets
        uint256[] memory aliceAssetsAfter = platform.getCreatorAssets(alice);
        assertEq(aliceAssetsAfter.length, 3);
        
        // Verify Bob has 1 asset
        uint256[] memory bobAssets = platform.getCreatorAssets(bob);
        assertEq(bobAssets.length, 1);
    }

    function test_getAllAssets() public {
        // Initially no assets
        uint256[] memory initialAssets = platform.getAllAssets();
        assertEq(initialAssets.length, 0);
        
        // Create assets from different creators
        vm.prank(alice);
        platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.MUSIC,
            "Alice Song", "Desc", "ipfs://alice", 5000, 0.01 ether, 25
        );
        
        vm.prank(bob);
        platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.ART,
            "Bob Art", "Desc", "ipfs://bob", 6000, 0.02 ether, 30
        );
        
        vm.prank(charlie);
        platform.createAsset(
            UniversalAssetTokenizationPlatform.AssetType.VIDEO,
            "Charlie Video", "Desc", "ipfs://charlie", 4000, 0.03 ether, 20
        );
        
        // Get all assets
        uint256[] memory allAssets = platform.getAllAssets();
        assertEq(allAssets.length, 3);
        assertEq(allAssets[0], 0);
        assertEq(allAssets[1], 1);
        assertEq(allAssets[2], 2);
    }

    // Events to match the contract
    event AssetCreated(uint256 indexed assetId, address indexed creator, UniversalAssetTokenizationPlatform.AssetType assetType, string title);
}