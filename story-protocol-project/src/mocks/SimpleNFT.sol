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

contract AssetNFT is ERC721, Ownable {
    uint256 private _tokenCounter;
    mapping(uint256 => string) private _tokenURIs;
    
    constructor() ERC721("Universal Asset NFT", "UANFT") Ownable(msg.sender) {
        _tokenCounter = 0;
    }
    
    function mint(address to, string memory tokenURI) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenCounter;
        _tokenCounter++;
        
        _mint(to, tokenId);
        _tokenURIs[tokenId] = tokenURI;
        
        return tokenId;
    }
    
    function nextTokenId() external view returns (uint256) {
        return _tokenCounter;
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return _tokenURIs[tokenId];
    }
    
    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        _tokenURIs[tokenId] = uri;
    }
}

contract AssetShareToken is ERC20, Ownable {
    address public immutable PLATFORM;
    uint256 public immutable ASSET_ID;
    uint256 public constant TOTAL_SHARES = 10000;

    struct ShareAllocation {
        uint256 creatorShares;
        uint256 publicShares;
        uint256 pricePerShare;
        bool saleActive;
    }
    ShareAllocation public allocation;

    modifier onlyPlatform() {
        require(msg.sender == PLATFORM, "Only platform");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address creator,
        uint256 assetId,
        uint256 creatorSharesPercent,
        uint256 pricePerShare
    ) ERC20(name, symbol) Ownable(creator) {
        PLATFORM = msg.sender;
        ASSET_ID = assetId;
        
        uint256 creatorShares = (TOTAL_SHARES * creatorSharesPercent) / 10000;
        uint256 publicShares = TOTAL_SHARES - creatorShares;

        allocation = ShareAllocation({
            creatorShares: creatorShares,
            publicShares: publicShares,
            pricePerShare: pricePerShare,
            saleActive: true
        });
        
        _mint(creator, creatorShares);
    }

    function buyShares(uint256 shareAmount) external payable {
        require(allocation.saleActive, "Sale not active");
        require(shareAmount > 0, "Must buy at least 1 share");
        require(shareAmount <= allocation.publicShares, "Not enough shares available");
        require(msg.value >= shareAmount * allocation.pricePerShare, "Insufficient payment");
        
        allocation.publicShares -= shareAmount;
        _mint(msg.sender, shareAmount);
        
        if (msg.value > shareAmount * allocation.pricePerShare) {
            payable(msg.sender).transfer(msg.value - (shareAmount * allocation.pricePerShare));
        }
    }

    function toggleSale() external onlyOwner {
        allocation.saleActive = !allocation.saleActive;
    }
    
    function updatePrice(uint256 newPrice) external onlyOwner {
        allocation.pricePerShare = newPrice;
    }
    
    function getRemainingShares() external view returns (uint256) {
        return allocation.publicShares;
    }
}

contract UniversalAssetTokenizationPlatform is ERC721Holder, ReentrancyGuard {
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;
    ILicensingModule public immutable LICENSING_MODULE;
    IPILicenseTemplate public immutable PIL_TEMPLATE;
    address public immutable ROYALTY_POLICY_LAP;
    address public immutable WIP;

    AssetNFT public immutable ASSET_NFT;

    enum AssetType { MUSIC, POETRY, DANCE, ART, VIDEO, WRITING, CODE, OTHER }
    enum VerificationStatus { PENDING, VERIFIED, REJECTED }

    struct Asset {
        uint256 nftTokenId;
        address ipId;
        uint256 licenseTermsId;
        address creator;
        AssetType assetType;
        string title;
        string description;
        string metadataURI;
        address shareTokenAddress;
        uint256 totalRoyaltiesCollected;
        bool exists;
        VerificationStatus verificationStatus;
    }

    struct RoyaltyDistribution {
        uint256 totalAmount;
        uint256 timestamp;
        mapping(address => uint256) claimedAmounts;
    }
    
    struct CreatorProfile {
        address wallet;
        string[] verifiedPlatforms;
        mapping(string => bool) platformVerified;
        uint256 assetsCreated;
        bool isVerified;
        VerificationStatus verificationStatus;
    }

    uint256 private _assetCounter;
    mapping(uint256 => Asset) public assets;
    mapping(address => CreatorProfile) public creators;
    mapping(uint256 => RoyaltyDistribution[]) public royaltyDistributions;
    mapping(uint256 => uint256) public assetRoyaltyBalance;

    address public platformOwner;
    uint256 public platformFeePercent = 500;    
    uint256 public constant MAX_PLATFORM_FEE = 1000;

    event AssetCreated(uint256 indexed assetId, address indexed creator, AssetType assetType, string title);
    event SharesPurchased(uint256 indexed assetId, address indexed buyer, uint256 shares, uint256 amount);
    event RoyaltiesDeposited(uint256 indexed assetId, uint256 amount);
    event RoyaltiesClaimed(uint256 indexed assetId, address indexed claimer, uint256 amount);
    event CreatorVerified(address indexed creator, string platform);
    event AssetVerificationUpdated(uint256 indexed assetId, VerificationStatus status);

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

        // Register the NFT as an IP Asset
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
            verificationStatus: VerificationStatus.PENDING
        });

        
        creators[msg.sender].wallet = msg.sender;
        creators[msg.sender].assetsCreated++;
        
        emit AssetCreated(assetId, msg.sender, assetType, title);
    }

    function buyAssetShares(uint256 assetId, uint256 shareAmount) external payable nonReentrant {
        require(assets[assetId].exists, "Asset does not exist");
        
        AssetShareToken shareToken = AssetShareToken(assets[assetId].shareTokenAddress);
        shareToken.buyShares{value: msg.value}(shareAmount);
        
        emit SharesPurchased(assetId, msg.sender, shareAmount, msg.value);
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
        
        emit RoyaltiesDeposited(assetId, royaltyAmount);
    }

    function distributeRoyalties(uint256 assetId) external nonReentrant {
        require(assets[assetId].exists, "Asset does not exist");
        require(assetRoyaltyBalance[assetId] > 0, "No royalties to distribute");
        
        AssetShareToken shareToken = AssetShareToken(assets[assetId].shareTokenAddress);
        uint256 distributionAmount = assetRoyaltyBalance[assetId];
        
       
        royaltyDistributions[assetId].push();
        uint256 distributionIndex = royaltyDistributions[assetId].length - 1;
        
        RoyaltyDistribution storage distribution = royaltyDistributions[assetId][distributionIndex];
        distribution.totalAmount = distributionAmount;
        distribution.timestamp = block.timestamp;
        
        
        assetRoyaltyBalance[assetId] = 0;
    }

    function claimRoyalties(uint256 assetId, uint256 distributionIndex) external nonReentrant {
        require(assets[assetId].exists, "Asset does not exist");
        require(distributionIndex < royaltyDistributions[assetId].length, "Invalid distribution");
        
        RoyaltyDistribution storage distribution = royaltyDistributions[assetId][distributionIndex];
        require(distribution.claimedAmounts[msg.sender] == 0, "Already claimed");
        
        AssetShareToken shareToken = AssetShareToken(assets[assetId].shareTokenAddress);
        uint256 userShares = shareToken.balanceOf(msg.sender);
        require(userShares > 0, "No shares owned");
        
        uint256 totalSupply = shareToken.totalSupply();
        uint256 userRoyaltyShare = (distribution.totalAmount * userShares) / totalSupply;
        
        require(userRoyaltyShare > 0, "No royalties to claim");
        
       
        distribution.claimedAmounts[msg.sender] = userRoyaltyShare;
        
        
        payable(msg.sender).transfer(userRoyaltyShare);
        
        emit RoyaltiesClaimed(assetId, msg.sender, userRoyaltyShare);
    }

    function submitVerification(string memory platformUrl) external {
        creators[msg.sender].verificationStatus = VerificationStatus.PENDING;
    }
    
    function verifyCreator(address creator, string memory platform) external onlyPlatformOwner {
        creators[creator].platformVerified[platform] = true;
        creators[creator].verifiedPlatforms.push(platform);
        creators[creator].isVerified = true;
        
        emit CreatorVerified(creator, platform);
    }
    
    function updateAssetVerification(uint256 assetId, VerificationStatus status) external onlyPlatformOwner {
        require(assets[assetId].exists, "Asset does not exist");
        assets[assetId].verificationStatus = status;
        
        emit AssetVerificationUpdated(assetId, status);
    }
    
    function getAsset(uint256 assetId) external view returns (Asset memory) {
        require(assets[assetId].exists, "Asset does not exist");
        return assets[assetId];
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
    
    function getAllAssets() external view returns (uint256[] memory) {
        uint256[] memory allAssets = new uint256[](_assetCounter);
        for (uint256 i = 0; i < _assetCounter; i++) {
            allAssets[i] = i;
        }
        return allAssets;
    }
    
    function getUserShares(address user, uint256 assetId) external view returns (uint256) {
        if (!assets[assetId].exists) return 0;
        AssetShareToken shareToken = AssetShareToken(assets[assetId].shareTokenAddress);
        return shareToken.balanceOf(user);
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
    
    function updatePlatformFee(uint256 newFeePercent) external onlyPlatformOwner {
        require(newFeePercent <= MAX_PLATFORM_FEE, "Fee too high");
        platformFeePercent = newFeePercent;
    }
    
    function withdrawPlatformFees() external onlyPlatformOwner {
        payable(platformOwner).transfer(address(this).balance);
    }
    
    function getRoyaltyDistributionCount(uint256 assetId) external view returns (uint256) {
        return royaltyDistributions[assetId].length;
    }
    
    function getRoyaltyDistribution(uint256 assetId, uint256 distributionIndex) 
        external 
        view 
        returns (uint256 totalAmount, uint256 timestamp, uint256 claimedAmount) 
    {
        require(distributionIndex < royaltyDistributions[assetId].length, "Invalid distribution");
        RoyaltyDistribution storage distribution = royaltyDistributions[assetId][distributionIndex];
        
        return (
            distribution.totalAmount,
            distribution.timestamp,
            distribution.claimedAmounts[msg.sender]
        );
    }
    
    function pause() external onlyPlatformOwner {
        // Implement pause functionality if needed
    }
    
    receive() external payable {
        // Allow contract to receive Ether
    }
}