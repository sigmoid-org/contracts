// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

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
        uint256 yes_votes;
        uint256 no_votes;
    }

    struct RoyaltyDistribution {
        uint256 totalAmount;
        uint256 timestamp;
        uint256 totalSharesAtDistribution; 
    }
    
    struct CreatorProfile {
        address wallet;
        string[] verifiedPlatforms;
        mapping(string => bool) platformVerified;
        uint256 assetsCreated;
        bool isVerified;
        VerificationStatus verificationStatus;
        string profilephotoIPFS;
        string bio;
        string platformName;
    }

    struct Deposition {
        uint256 amount;
        uint256 timestamp;
    }

struct AssetWithVote {
        Asset asset;
        uint256 vote;
        address[] verifiers;

    }

      struct UserAssets {
        Asset asset;
        uint256 balance;
    }
    