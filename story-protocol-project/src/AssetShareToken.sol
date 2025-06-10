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
