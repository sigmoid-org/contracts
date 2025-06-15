
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./AssetNFT.sol";
import "./AssetShareToken.sol";
import "./utils/structs.sol";


contract UniversalAssetTokenizationPlatform is ERC721Holder, ReentrancyGuard {
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;
    ILicensingModule public immutable LICENSING_MODULE;
    IPILicenseTemplate public immutable PIL_TEMPLATE;
    address public immutable ROYALTY_POLICY_LAP;
    address public immutable WIP;
    AssetNFT public immutable ASSET_NFT;
    
    uint256 private _assetCounter;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public distributionClaims;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public distributionShares;
    mapping(uint256 => RoyaltyDistribution[]) public royaltyDistributions;

    mapping(uint256 => uint256) public distributionCount;
    mapping(uint256 => Asset) public assets;
    mapping(address => CreatorProfile) public creators;
    mapping(uint256 => uint256) public assetRoyaltyBalance;
    mapping(uint256 => mapping(address => bool)) private assetToAddressToVote;
    mapping(uint256 => address[]) public assetToVerifiers;
    mapping(address => address[]) public addressToReporters;
    mapping(address => address[]) public addressToReported;
    mapping(address => uint256[]) public userToOwnedAssets;
    mapping(address => uint256[]) public userToOwnedAssetsNFTIds;
    mapping(address => Deposition[]) public userToDepositions;

    address public platformOwner;
    uint256 public platformFeePercent = 500;    
    uint256 public constant MAX_PLATFORM_FEE = 1000;

    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner");
        _;
    }
    
    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address pilTemplate,
        address royaltyPolicyLAP,
        address wip
    ) {
        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = ILicensingModule(licensingModule);
        PIL_TEMPLATE = IPILicenseTemplate(pilTemplate);
        ROYALTY_POLICY_LAP = royaltyPolicyLAP;
        WIP = wip;
        
        ASSET_NFT = new AssetNFT();
        platformOwner = msg.sender;
    }
    
    function createAsset( 
        AssetType assetType,
        string memory title,
        string memory description,
        string memory metadataURI,
        uint256 creatorSharesPercent, 
        uint256 pricePerShare,
        uint256 commercialRevSharePercent 
    ) external returns (uint256 assetId) {
        require(creatorSharesPercent <= 9000, "Creator cannot own more than 90%");
        require(creatorSharesPercent >= 1000, "Creator must own at least 10%");
        require(commercialRevSharePercent <= 100, "Commercial rev share cannot exceed 100%");

        assetId = _assetCounter++;
        
        
        string memory nftMetadata = string(abi.encodePacked(
            "Asset: ", title, " | Type: ", _assetTypeToString(assetType)
        ));
        
        
        uint256 nftTokenId = ASSET_NFT.mint(address(this), nftMetadata);
        address ipId = IP_ASSET_REGISTRY.register(block.chainid, address(ASSET_NFT), nftTokenId);
        
        uint32 commercialRevShare = uint32(commercialRevSharePercent * 1_000_000); // Convert to basis points (1% = 1_000_000)
        
        uint256 licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: commercialRevShare,
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: WIP
            })
        );
        
        
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
        
        
        ASSET_NFT.transferFrom(address(this), msg.sender, nftTokenId);
        
        
        string memory shareTokenName = string(abi.encodePacked(title, " Shares"));
        string memory shareTokenSymbol = string(abi.encodePacked("$", _assetTypeToString(assetType)));

        AssetShareToken shareToken = new AssetShareToken(
            shareTokenName,
            shareTokenSymbol,
            msg.sender,
            assetId,
            creatorSharesPercent,
            pricePerShare
        );

        assets[assetId] = Asset({
            nftTokenId: nftTokenId,
            ipId: ipId,
            licenseTermsId: licenseTermsId,
            creator: msg.sender,
            assetType: assetType,
            title: title,
            description: description,
            metadataURI: metadataURI,
            shareTokenAddress: address(shareToken),
            totalRoyaltiesCollected: 0,
            exists: true,
            verificationStatus: VerificationStatus.PENDING,
            yes_votes: 1,
            no_votes: 0
        });
        creators[msg.sender].wallet = msg.sender;
        creators[msg.sender].assetsCreated++;
        userToOwnedAssetsNFTIds[msg.sender].push(nftTokenId);
        userToOwnedAssets[msg.sender].push(assetId);
        assetToAddressToVote[assetId][msg.sender] = true;
        assetToVerifiers[assetId].push(msg.sender);
    }

    function buyAssetShares(uint256 assetId, uint256 shareAmount) external payable nonReentrant {
        require(assets[assetId].exists, "Asset does not exist");
        AssetShareToken shareToken = AssetShareToken(assets[assetId].shareTokenAddress);
        shareToken.buyShares{value: msg.value}(shareAmount, msg.sender);
        address creator = shareToken.owner(); 
        payable(creator).transfer(msg.value); 
        userToOwnedAssets[msg.sender].push(assetId);
        userToOwnedAssetsNFTIds[msg.sender].push(assets[assetId].nftTokenId);
    }

    function depositRoyalties(uint256 assetId) external payable nonReentrant {
        require(assets[assetId].exists, "Asset does not exist");
        require(msg.value > 0, "Must deposit some amount");
        
        uint256 platformFee = (msg.value * platformFeePercent) / 10000;
        uint256 royaltyAmount = msg.value - platformFee;
        assetRoyaltyBalance[assetId] += royaltyAmount;
        assets[assetId].totalRoyaltiesCollected += royaltyAmount;
        if (platformFee > 0) {
            payable(platformOwner).transfer(platformFee);
        }
        Deposition memory deposition = Deposition({
            amount: msg.value,
            timestamp: block.timestamp
        });
        userToDepositions[msg.sender].push(deposition);
    }

    function distributeRoyalties(uint256 assetId) external nonReentrant {
        require(assets[assetId].exists, "Asset does not exist");
        require(assetRoyaltyBalance[assetId] > 0, "No royalties to distribute");
        
        AssetShareToken shareToken = AssetShareToken(assets[assetId].shareTokenAddress);
        uint256 distributionAmount = assetRoyaltyBalance[assetId];
        uint256 totalShares = shareToken.TOTAL_SHARES();
        
        // Create new distribution with snapshot of total shares
        RoyaltyDistribution memory newDistribution = RoyaltyDistribution({
            totalAmount: distributionAmount,
            timestamp: block.timestamp,
            totalSharesAtDistribution: totalShares
        });
        
        // Add to array
        royaltyDistributions[assetId].push(newDistribution);
        uint256 distributionIndex = royaltyDistributions[assetId].length - 1;
        (address[] memory holders, uint256[] memory balances) = shareToken.getAllShareholders();
        for (uint256 i = 0; i < holders.length; i++) {
            if (balances[i] > 0) {
                distributionShares[assetId][distributionIndex][holders[i]] = balances[i];
            }
        }
        distributionCount[assetId]++;
        assetRoyaltyBalance[assetId] = 0;
    }
    function claimRoyalties(uint256 assetId, uint256 distributionIndex) external nonReentrant {
        require(assets[assetId].exists, "Asset does not exist");
        require(distributionIndex < royaltyDistributions[assetId].length, "Invalid distribution index");
        require(distributionClaims[assetId][distributionIndex][msg.sender] == 0, "Already claimed");
        uint256 userSharesAtDistribution = distributionShares[assetId][distributionIndex][msg.sender];
        require(userSharesAtDistribution > 0, "No shares owned at distribution time");
        RoyaltyDistribution storage distribution = royaltyDistributions[assetId][distributionIndex];
        uint256 userPortion = (distribution.totalAmount * userSharesAtDistribution) / distribution.totalSharesAtDistribution;
        require(userPortion > 0, "No royalties to claim");
        distributionClaims[assetId][distributionIndex][msg.sender] = userPortion;
        payable(msg.sender).transfer(userPortion);
    }

    struct RoyaltyDistributionView {
        uint256 totalAmount;
        uint256 timestamp;
        uint256 claimedAmount;
    }

    function getAllDistributions(uint256 assetId) external view returns (
        uint256[] memory totalAmounts,
        uint256[] memory timestamps,
        bool[] memory claimed,
        uint256[] memory claimableAmounts,
        uint256 totalClaimable
    ) {
        require(assets[assetId].exists, "Asset does not exist");
        
        uint256 length = royaltyDistributions[assetId].length;
        totalAmounts = new uint256[](length);
        timestamps = new uint256[](length);
        claimed = new bool[](length);
        claimableAmounts = new uint256[](length);
        totalClaimable = 0;
        
        for (uint256 i = 0; i < length; i++) {
            RoyaltyDistribution storage distribution = royaltyDistributions[assetId][i];
            bool userClaimed = distributionClaims[assetId][i][msg.sender] > 0;
            
            totalAmounts[i] = distribution.totalAmount;
            timestamps[i] = distribution.timestamp;
            claimed[i] = userClaimed;
            
            if (!userClaimed) {
                uint256 userSharesAtDistribution = distributionShares[assetId][i][msg.sender];
                if (userSharesAtDistribution > 0) {
                    uint256 claimable = (distribution.totalAmount * userSharesAtDistribution) / distribution.totalSharesAtDistribution;
                    claimableAmounts[i] = claimable;
                    totalClaimable += claimable;
                }
            }
        }
    }
    
    // function submitVerification(string memory platformUrl) external {
    //     creators[msg.sender].verificationStatus = VerificationStatus.PENDING;
    // }
    
    // function verifyCreator(address creator, string memory platform) external onlyPlatformOwner {
    //     creators[creator].platformVerified[platform] = true;
    //     creators[creator].verifiedPlatforms.push(platform);
    //     creators[creator].isVerified = true;
    // }
    
    function updateAssetVerification(uint256 assetId, VerificationStatus status) external onlyPlatformOwner {
        require(assets[assetId].exists, "Asset does not exist");
        assets[assetId].verificationStatus = status;
    }

    function getUserDepositions(address user) external view returns (Deposition[] memory) {
        return userToDepositions[user];
    }
    
    function getAsset(uint256 assetId) external view returns (Asset memory, address[] memory verifiers) {
        require(assets[assetId].exists, "Asset does not exist");
        address[] memory verifiers = assetToVerifiers[assetId];
        return (assets[assetId],verifiers); 
    }
    
    function getCreatorAssets(address creator) external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < _assetCounter; i++) {
            if (assets[i].creator == creator) {
                count++;
            }
        }
        
        uint256[] memory creatorAssets = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < _assetCounter; i++) {
            if (assets[i].creator == creator) {
                creatorAssets[index] = i;
                index++;
            }
        }
        
        return creatorAssets;
    }
    function hasVoted(uint256 assetId, address user) external view returns (bool) {
        return assetToAddressToVote[assetId][user];
    }

    function _hasVoted(uint256 assetId, address user) internal view returns (bool) {
        return assetToAddressToVote[assetId][user];
    }
    
    function getAllAssets() external view returns (AssetWithVote[] memory) {
        AssetWithVote[] memory allAssets = new AssetWithVote[](_assetCounter);

        
        for (uint256 i = 0; i < _assetCounter; i++) {
            allAssets[i] = AssetWithVote({
                asset: assets[i],
                vote: _hasVoted(i, msg.sender) ? 1 : 0,
                verifiers: assetToVerifiers[i]
            });
        }
        
        return allAssets;
    }

    function getUserShares(address user, uint256 assetId) external view returns (uint256) {
        if (!assets[assetId].exists) return 0;
        AssetShareToken shareToken = AssetShareToken(assets[assetId].shareTokenAddress);
        return shareToken.balanceOf(user);
    }

    function getAllAssetShares() external view returns (UserAssets[] memory) {
        uint256[] memory ownedAssetIds = userToOwnedAssets[msg.sender];
        uint256 length = ownedAssetIds.length;

        UserAssets[] memory userShares = new UserAssets[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 assetId = ownedAssetIds[i];
            AssetShareToken shareToken = AssetShareToken(assets[assetId].shareTokenAddress);
            userShares[i] = UserAssets({
                asset: assets[assetId],
                balance: shareToken.balanceOf(msg.sender)
            });
        }

        return userShares;
    }

    function getAllUserAssets() external view returns (Asset[] memory) {
        uint256 length = userToOwnedAssets[msg.sender].length;
        Asset[] memory userAssets = new Asset[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 assetId = userToOwnedAssets[msg.sender][i];
            userAssets[i] = assets[assetId];
        }
        return userAssets;
    }

    function _assetTypeToString(AssetType assetType) internal pure returns (string memory) {
        if (assetType == AssetType.MUSIC) return "MUSIC";
        if (assetType == AssetType.POETRY) return "POETRY";
        if (assetType == AssetType.DANCE) return "DANCE";
        if (assetType == AssetType.ART) return "ART";
        if (assetType == AssetType.VIDEO) return "VIDEO";
        if (assetType == AssetType.WRITING) return "WRITING";
        if (assetType == AssetType.CODE) return "CODE";
        return "OTHER";
    }
    

    function getRoyaltyDistribution(uint256 assetId, uint256 distributionIndex) external view returns (
        uint256 totalAmount,
        uint256 timestamp,
        bool claimed,
        uint256 claimableAmount
    ) {
        require(distributionIndex < royaltyDistributions[assetId].length, "Invalid distribution index");
        
        RoyaltyDistribution storage distribution = royaltyDistributions[assetId][distributionIndex];
        bool userClaimed = distributionClaims[assetId][distributionIndex][msg.sender] > 0;
        
        uint256 claimable = 0;
        if (!userClaimed) {
            uint256 userSharesAtDistribution = distributionShares[assetId][distributionIndex][msg.sender];
            if (userSharesAtDistribution > 0) {
                claimable = (distribution.totalAmount * userSharesAtDistribution) / distribution.totalSharesAtDistribution;
            }
        }
        
        return (
            distribution.totalAmount,
            distribution.timestamp,
            userClaimed,
            claimable
        );
    }


    function updateCreatorProfileDetails(string memory _name, string memory _profilephotoIPFS, string memory _bio) external {
        require(creators[msg.sender].wallet != address(0), "Creator does not exist");
        creators[msg.sender].platformName = _name;
        creators[msg.sender].profilephotoIPFS = _profilephotoIPFS;
        creators[msg.sender].bio = _bio;
    }

    function voteOnAsset(uint256 assetId, bool vote) external {
        if(assetToAddressToVote[assetId][msg.sender] == true) return;
        require(assets[assetId].exists, "Asset does not exist");
        if(vote) {
            assets[assetId].yes_votes++;
            assetToVerifiers[assetId].push(msg.sender);
        } else {
            assets[assetId].no_votes++;
        }
        assetToAddressToVote[assetId][msg.sender] = true;
        assetToVerifiers[assetId].push(msg.sender);
    }

    function registerCreator(
        string memory _name, 
        string memory _profilephotoIPFS, 
        string memory _bio
    ) external {
        require(creators[msg.sender].wallet == address(0), "Creator already registered");
        
        CreatorProfile storage newCreator = creators[msg.sender];
        newCreator.wallet = msg.sender;
        newCreator.platformName = _name;
        newCreator.profilephotoIPFS = _profilephotoIPFS;
        newCreator.bio = _bio;
        newCreator.assetsCreated = 0;
        newCreator.isVerified = false;
        newCreator.verificationStatus = VerificationStatus.PENDING;
    }

    function getCreatorBasicInfo(address creator) external view returns (
        address walletAddress,
        string memory name,
        string memory photo,
        string memory bio,
        bool isVerified,
        address[] memory reportersArray
    ) {
        address[] memory reporters = addressToReporters[creator];
        CreatorProfile storage profile = creators[creator];
        return (
            profile.wallet,
            profile.platformName,
            profile.profilephotoIPFS,
            profile.bio,
            profile.isVerified,
            reporters
        );
    }

    function isPlatformVerified(address creator, string memory platform) external view returns (bool) {
        return creators[creator].platformVerified[platform];
    }

    function reportUser(address user) external {
        for(uint256 i = 0; i < addressToReporters[msg.sender].length; i++) {
            if(addressToReporters[msg.sender][i] == user) {
                return;
            }
        }
        addressToReported[msg.sender].push(user);
        addressToReporters[user].push(msg.sender);
    }

    function pause() external onlyPlatformOwner {
        // Implement pause functionality if needed
    }
    
    receive() external payable {
        // Allow contract to receive Ether
    }
}