// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "@storyprotocol/core/interfaces/registries/ILicenseRegistry.sol";

import { UniversalAssetTokenizationPlatform } from "../src/UniversalAssetTokenisationPlatform.sol";
import { AssetNFT } from "../src/AssetNFT.sol";
import { AssetShareToken } from "../src/AssetShareToken.sol";
import "../src/utils/structs.sol";
import "../src/utils/errors.sol";

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

    function test_step1_createAsset() public {
        vm.startPrank(alice);
        
        uint256 assetId = platform.createAsset(
            AssetType.MUSIC,
            "Test Song",
            "Test Description",
            "ipfs://test-hash",
            5000, // 50% creator shares
            0.01 ether,
            25
        );
        
        vm.stopPrank();
        
        // Basic checks
        (Asset memory asset, ) = platform.getAsset(assetId);
        assertEq(asset.creator, alice);
        assertTrue(asset.exists);
        
        console.log(" Asset created successfully with ID:", assetId);
    }

    function test_step2_buyShares() public {
        vm.startPrank(alice);
        
        uint256 assetId = platform.createAsset(
            AssetType.MUSIC,
            "Test Song",
            "Test Description", 
            "ipfs://test-hash",
            5000,
            0.01 ether,
            25
        );
        
        vm.stopPrank();
        
        // Bob buys shares
        vm.startPrank(bob);
        uint256 sharesToBuy = 100;
        uint256 cost = sharesToBuy * 0.01 ether;
        
        console.log("Bob attempting to buy %s shares for %s wei", sharesToBuy, cost);
        
        platform.buyAssetShares{value: cost}(assetId, sharesToBuy);
        vm.stopPrank();
        
        (Asset memory asset, ) = platform.getAsset(assetId);
        AssetShareToken shareToken = AssetShareToken(asset.shareTokenAddress);
        
        uint256 bobBalance = shareToken.balanceOf(bob);
        assertEq(bobBalance, sharesToBuy);
        
        console.log(" Bob successfully bought", bobBalance, "shares");
    }

    // Enhanced debug version of depositRoyalties test
    function test_step3_depositRoyalties_debug() public {
        console.log("=== DEBUGGING DEPOSIT ROYALTIES ===");
        
        vm.startPrank(alice);
        uint256 assetId = platform.createAsset(
            AssetType.MUSIC,
            "Test Song",
            "Test Description",
            "ipfs://test-hash", 
            5000,
            0.01 ether,
            25
        );
        vm.stopPrank();
        
        console.log("Asset ID created:", assetId);
        
        // Verify asset exists
        (Asset memory asset, ) = platform.getAsset(assetId);
        assertTrue(asset.exists, "Asset should exist");
        console.log(" Asset exists check passed");
        
        // Check platform fee percent exists
        try platform.platformFeePercent() returns (uint256 feePercent) {
            console.log("Platform fee percent:", feePercent);
        } catch {
            console.log(" platformFeePercent() function missing or reverting");
            return;
        }
        
        // Check if assetRoyaltyBalance mapping exists
        try platform.assetRoyaltyBalance(assetId) returns (uint256 balance) {
            console.log(" Initial royalty balance:", balance);
        } catch {
            console.log(" assetRoyaltyBalance() function missing or reverting");
            return;
        }
        
        vm.startPrank(alice);
        uint256 royaltyAmount = 0.1 ether;
        console.log("Charlie attempting to deposit", royaltyAmount, "wei");
        
        try platform.depositRoyalties{value: royaltyAmount}(assetId) {
            console.log(" Deposit successful");
        } catch Error(string memory reason) {
            console.log(" Deposit failed with reason:", reason);
            revert(reason);
        } catch Panic(uint errorCode) {
            console.log(" Deposit failed with panic code:", errorCode);
            revert("Panic error");
        } catch (bytes memory lowLevelData) {
            console.log(" Deposit failed with low-level error");
            console.logBytes(lowLevelData);
            revert("Low-level error");
        }
        
        vm.stopPrank();
    }

    // Test to check if missing functions exist
    function test_check_required_functions() public {
        console.log("=== CHECKING REQUIRED FUNCTIONS ===");
        
        // Check if platform has required functions
        try platform.platformFeePercent() returns (uint256) {
            console.log(" platformFeePercent() exists");
        } catch {
            console.log(" platformFeePercent() missing");
        }
        
        // Check if userToDepositions mapping exists (used in depositRoyalties)
        // This might be missing based on the error
        console.log(" Check if userToDepositions mapping exists in your contract");
        console.log(" Check if platformOwner variable exists in your contract");
    }

    // Minimal test for distributeRoyalties
    function test_step5_distributeRoyalties_debug() public {
        console.log("=== DEBUGGING DISTRIBUTE ROYALTIES ===");
        
        vm.startPrank(alice);
        uint256 assetId = platform.createAsset(
            AssetType.MUSIC,
            "Test Song",
            "Test Description",
            "ipfs://test-hash",
            5000,
            0.01 ether,
            25
        );
        vm.stopPrank();
        
        console.log("Asset created:", assetId);
        
        // First, let's see if we can even call distributeRoyalties without deposits
        try platform.distributeRoyalties(assetId) {
            console.log(" distributeRoyalties should have failed but didn't");
        } catch Error(string memory reason) {
            console.log(" distributeRoyalties correctly failed with:", reason);
        } catch {
            console.log(" distributeRoyalties failed with unknown error");
        }
    }

    function test_minimal_reproduction() public {
        // Absolute minimal test to see what works
        vm.startPrank(alice);
        
        uint256 assetId = platform.createAsset(
            AssetType.MUSIC,
            "Test",
            "Test",
            "ipfs://test",
            5000,
            0.01 ether,
            25
        );
        
        vm.stopPrank();
        
        // Just check the asset exists
        (Asset memory asset, ) = platform.getAsset(assetId);
        assertTrue(asset.exists, "Asset should exist");
        
        // Check share token was created
        assertTrue(asset.shareTokenAddress != address(0), "Share token should be created");
        
        // Check Alice has shares
        AssetShareToken shareToken = AssetShareToken(asset.shareTokenAddress);
        uint256 aliceBalance = shareToken.balanceOf(alice);
        assertEq(aliceBalance, 5000, "Alice should have 5000 shares");
        
        console.log(" Minimal reproduction test passed");
        console.log("Alice balance:", aliceBalance);
    }
}