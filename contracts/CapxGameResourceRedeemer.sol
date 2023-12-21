// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ICapxGameResource} from "contracts/interfaces/ICapxGameResource.sol";
import {ICapxNFT} from "contracts/interfaces/ICapxNFT.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CapxGameResourceRedeemer is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    ICapxGameResource public capxGameResource;
    ICapxNFT public capxNFT;
    IERC20 public capxToken;

    struct LootboxTypes {
        uint256 resources;
        uint256 nfts;
        mapping(uint256 => uint256) capxTokens;
    }

    LootboxTypes public lootboxesRedeemed;

    uint256 public lootboxesMinted;

    mapping(address => mapping(uint256 => mapping(uint256 => uint256)))
        private minedResources;

    mapping(address => uint256) public userCraftedLootboxes;

    uint256 public maxResourcesLootboxes = 4600000;
    uint256 public maxNFTLootboxes = 10000;

    mapping(uint256 => uint256) private capxTokenCaps;
    uint256[] public capxTokenAmounts; // Array to store different token amounts [ 2, 3, 5, 10]

    mapping(uint256 => address) private redeemedLootboxOwners;

    address public authorizedSigner;

    event CapxLootBoxRedeemedResource(
        address player,
        uint256 lootBoxID,
        uint256[] resources,
        uint256[] amounts
    );

    event CapxLootBoxRedeemedNFT(
        address player,
        uint256 lootBoxID,
        uint256 capxNftID
    );

    event CapxLootBoxRedeemedTokens(
        address player,
        uint256 lootBoxID,
        uint256 capxTokens
    );

    constructor() initializer {}

    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    function initialize(address _authorizedSigner) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        authorizedSigner = _authorizedSigner;
    }

    function updateGameResourceContractAddress(address _capxGameResource)
        external
        onlyOwner
    {
        require(
            _capxGameResource != address(0),
            "CapxRedemption: Invalid Capx Game Resource contract address"
        );
        capxGameResource = ICapxGameResource(_capxGameResource);
    }

    function updateNFTContractAddress(address _capxNFT) external onlyOwner {
        require(
            _capxNFT != address(0),
            "CapxRedemption: Invalid Capx NFT contract address"
        );
        capxNFT = ICapxNFT(_capxNFT);
    }

    function updateCapxTokenContract(address _capxToken) external onlyOwner {
        require(
            _capxToken != address(0),
            "CapxRedemption: Invalid Capx token contract address"
        );
        capxToken = IERC20(_capxToken);
    }

    function recoverSigner(bytes32 messagehash, bytes memory signature)
        internal
        pure
        returns (address)
    {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messagehash)
        );
        return ECDSA.recover(messageDigest, signature);
    }

    function initializeCapxTokenCaps(
        uint256[] memory _tokenAmounts,
        uint256[] memory _caps
    ) external onlyOwner {
        require(
            _tokenAmounts.length == _caps.length,
            "CapxRedemption: Element length of tokenAmounts must match length of caps"
        );

        capxTokenAmounts = _tokenAmounts;

        for (uint256 i = 0; i < _tokenAmounts.length; i++) {
            capxTokenCaps[_tokenAmounts[i]] = _caps[i];
        }
    }

    function mineResource(
        bytes32 _messageHash,
        bytes memory _signature,
        uint256 resource,
        uint256 amount,
        uint256 mineTimeStamp
    ) external nonReentrant {
        require(
            address(capxGameResource) != address(0),
            "CapxRedemption: Game resource contract address is not set"
        );

        require(
            minedResources[_msgSender()][resource][mineTimeStamp] != 0,
            "CapxRedemption: User has already claimed the resource."
        );

        require(
            keccak256(
                abi.encodePacked(_msgSender(), resource, amount, mineTimeStamp)
            ) == _messageHash,
            "CapxRedemption: Invalid MessageHash"
        );
        require(
            recoverSigner(_messageHash, _signature) == authorizedSigner,
            "CapxRedemption: Invalid Signer"
        );

        minedResources[_msgSender()][resource][mineTimeStamp] = amount;

        capxGameResource.mineResource(
            _msgSender(),
            resource,
            amount,
            mineTimeStamp
        );
    }

    // Burns the resources.
    function forgeLootbox() external nonReentrant {
        require(
            address(capxGameResource) != address(0),
            "CapxRedemption: Game resource contract address is not set"
        );

        userCraftedLootboxes[_msgSender()] += 1;

        capxGameResource.forgeLootbox(_msgSender());
    }

    // Mints the lootbox.
    function mintLootbox() external nonReentrant {
        require(
            lootboxesMinted + 1 <= maxLootboxes(),
            "CapxRedemption: Max cap for crafting lootboxes has reached."
        );
        require(
            userCraftedLootboxes[_msgSender()] > 0,
            "CapxRedemption: User has not forged lootboxes"
        );

        userCraftedLootboxes[_msgSender()] -= 1;

        lootboxesMinted += 1;
        capxGameResource.mintLootbox(_msgSender(), lootboxesMinted);
    }

    // Reveals the lootbox.
    function redeemLootbox(
        bytes32 _messageHash,
        bytes memory _signature,
        bytes calldata _redemptionData
    ) external nonReentrant {
        require(
            address(capxGameResource) != address(0),
            "CapxRedemption: Game resource contract address is not set"
        );
        require(
            address(capxNFT) != address(0),
            "CapxRedemption: NFT contract address is not set"
        );

        require(
            address(capxToken) != address(0),
            "CapxRedemption: Token contract address is not set"
        );

        uint256 redeemedLootboxID = capxGameResource.burnLootbox(_msgSender());

        require(
            redeemedLootboxOwners[redeemedLootboxID] == address(0),
            "CapxRedemption: User has already redeemed the lootboxId"
        );

        require(
            keccak256(abi.encodePacked(redeemedLootboxID, _redemptionData)) ==
                _messageHash,
            "CapxRedemption: Invalid MessageHash"
        );

        require(
            recoverSigner(_messageHash, _signature) == authorizedSigner,
            "CapxRedemption: Invalid Signer"
        );

        (
            uint256[] memory _resources,
            uint256[] memory _amounts,
            uint256 _capxTokenAmount,
            uint256 _lootBoxType
        ) = abi.decode(
                _redemptionData,
                (uint256[], uint256[], uint256, uint256)
            );

        redeemedLootboxOwners[redeemedLootboxID] = _msgSender();

        if (_lootBoxType == 1) {
            require(
                address(capxNFT) != address(0),
                "CapxRedemption: NFT contract not set"
            );

            require(
                lootboxesRedeemed.nfts + 1 <= maxNFTLootboxes,
                "CapxRedemption: Max cap for redeeming NFT has reached."
            );

            lootboxesRedeemed.nfts += 1;

            uint256 capxNFTID = capxNFT.mint(_msgSender());

            emit CapxLootBoxRedeemedNFT(
                _msgSender(),
                redeemedLootboxID,
                capxNFTID
            );
            return;
        } else if (_lootBoxType == 2) {
            require(
                address(capxToken) != address(0),
                "CapxRedemption: Token contract not set"
            );

            require(
                lootboxesRedeemed.capxTokens[_capxTokenAmount] + 1 <=
                    capxTokenCaps[_capxTokenAmount],
                "CapxRedemption: Lootboxes for the token amount are exhausted"
            );

            lootboxesRedeemed.capxTokens[_capxTokenAmount] += 1;

            require(IERC20(capxToken).approve(_msgSender(), _capxTokenAmount));

            IERC20(capxToken).safeTransfer(_msgSender(), _capxTokenAmount);

            emit CapxLootBoxRedeemedTokens(
                _msgSender(),
                redeemedLootboxID,
                _capxTokenAmount
            );
            return;
        } else if (_lootBoxType == 3) {
            require(
                address(capxGameResource) != address(0),
                "CapxRedemption: Game Resource contract not set"
            );

            require(
                lootboxesRedeemed.resources + 1 <= maxResourcesLootboxes,
                "CapxRedemption: Max cap for redeeming resources has reached."
            );

            lootboxesRedeemed.resources += 1;

            capxGameResource.redeemResources(
                _msgSender(),
                _resources,
                _amounts
            );

            emit CapxLootBoxRedeemedResource(
                _msgSender(),
                redeemedLootboxID,
                _resources,
                _amounts
            );
            return;
        }
    }

    function updateAuthorizedSigner(address _authorizedSigner)
        external
        onlyOwner
    {
        require(
            _authorizedSigner != address(0),
            "CapxResource: ZeroAddress NOT Allowed"
        );
        authorizedSigner = _authorizedSigner;
    }

    function maxLootboxes() internal view returns (uint256) {
        uint256 _maxLootboxes = maxResourcesLootboxes + maxNFTLootboxes;

        for (uint256 i = 0; i < capxTokenAmounts.length; i++) {
            _maxLootboxes += capxTokenCaps[capxTokenAmounts[i]];
        }

        return _maxLootboxes;
    }

    function updateMaxResourceLootboxes(uint256 _maxResourcesLootboxes)
        external
        onlyOwner
    {
        require(
            _maxResourcesLootboxes > 0,
            "CapxRedemption: Max resources lootboxes cannot be less than 0"
        );
        maxResourcesLootboxes = _maxResourcesLootboxes;
    }

    function updateMaxNFTLootboxes(uint256 _maxNFTLootboxes)
        external
        onlyOwner
    {
        require(
            _maxNFTLootboxes > 0,
            "CapxRedemption: Max NFT lootboxes cannot be less than 0"
        );
        maxNFTLootboxes = _maxNFTLootboxes;
    }

    function updateCapxTokenCap(uint256 tokenAmount, uint256 newCap)
        external
        onlyOwner
    {
        capxTokenCaps[tokenAmount] = newCap;
    }

    function getUserMinedResources(
        address miner,
        uint256 resourceId,
        uint256 timestamp
    ) external view returns (uint256 amount) {
        return minedResources[miner][resourceId][timestamp];
    }

    function getRedeemedLootboxes() public view returns (uint256) {
        uint256 totalRedeemed = lootboxesRedeemed.resources +
            lootboxesRedeemed.nfts;

        for (uint256 i = 0; i < capxTokenAmounts.length; i++) {
            totalRedeemed += lootboxesRedeemed.capxTokens[capxTokenAmounts[i]];
        }

        return totalRedeemed;
    }
}
