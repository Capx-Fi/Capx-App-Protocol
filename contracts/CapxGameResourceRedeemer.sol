// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    struct LootBoxCounts {
        uint256 resources;
        uint256 nfts;
        uint256 capxTokens;
        uint256 quantity; // Quantity of the lootboxes
    }

    uint256 public constant LOOTBOX = 5;

    LootBoxCounts public lootBoxMinted;

    mapping(address => mapping(uint256 => bool)) private craftedLootboxes;
    mapping(address => mapping(uint256 => mapping(uint256 => bool)))
        private minedResources;
    mapping(address => mapping(uint256 => bool)) private redeemedLootboxes;

    uint256 public maxResourcesLootboxes = 4600000;
    uint256 public maxNFTLootboxes = 10000;
    uint256 public maxCapxTokensLootboxes = 390000;

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
            !minedResources[_msgSender()][resource][mineTimeStamp],
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

        minedResources[_msgSender()][resource][mineTimeStamp] = true;

        capxGameResource.mineResource(
            _msgSender(),
            resource,
            amount,
            mineTimeStamp
        );
    }

    // Burns the resources.
    function craftLootbox(
        bytes32 _messageHash,
        bytes memory _signature,
        uint256 _timestamp
    ) external nonReentrant {
        require(
            address(capxGameResource) != address(0),
            "CapxRedemption: Game resource contract address is not set"
        );

        require(
            !craftedLootboxes[_msgSender()][_timestamp],
            "CapxRedemption: User has already crafted the lootbox."
        );

        require(
            keccak256(abi.encodePacked(_msgSender(), _timestamp)) ==
                _messageHash,
            "CapxRedemption: Invalid MessageHash"
        );
        require(
            recoverSigner(_messageHash, _signature) == authorizedSigner,
            "CapxRedemption: Invalid Signer"
        );

        craftedLootboxes[_msgSender()][_timestamp] = true;

        capxGameResource.craftLootbox(_msgSender());
    }

    // Mints the lootbox.
    function mintLootbox(
        bytes32 _messageHash,
        bytes memory _signature,
        uint256 _timestamp
    ) external nonReentrant {
        require(
            lootBoxMinted.quantity + 1 <= maxLootboxes(),
            "CapxRedemption: Max cap for crafting lootboxes has reached."
        );

        require(
            !minedResources[_msgSender()][LOOTBOX][_timestamp],
            "CapxRedemption: User has already minted the lootbox."
        );

        require(
            keccak256(abi.encodePacked(_msgSender(), _timestamp)) ==
                _messageHash,
            "CapxRedemption: Invalid MessageHash"
        );
        require(
            recoverSigner(_messageHash, _signature) == authorizedSigner,
            "CapxRedemption: Invalid Signer"
        );

        minedResources[_msgSender()][LOOTBOX][_timestamp] = true;
        lootBoxMinted.quantity += 1;
        capxGameResource.mintLootbox(_msgSender(), lootBoxMinted.quantity);
    }

    // Reveals the lootbox.
    function redeemLootbox(
        bytes32 _messageHash,
        bytes memory _signature,
        uint256 _timestamp,
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
            !redeemedLootboxes[_msgSender()][_timestamp],
            "CapxRedemption: User has already redeemed the lootbox."
        );

        require(
            keccak256(
                abi.encodePacked(_msgSender(), _timestamp, _redemptionData)
            ) == _messageHash,
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

        if (_lootBoxType == 1) {
            require(
                address(capxNFT) != address(0),
                "CapxRedemption: NFT contract not set"
            );

            require(
                lootBoxMinted.nfts + 1 <= maxNFTLootboxes,
                "CapxRedemption: Max cap for redeeming NFT has reached."
            );

            lootBoxMinted.nfts += 1;

            uint256 NFTRedeemedLootboxID = capxGameResource.burnLootbox(
                _msgSender()
            );

            uint256 capxNFTID = capxNFT.mint(_msgSender());

            emit CapxLootBoxRedeemedNFT(
                _msgSender(),
                NFTRedeemedLootboxID,
                capxNFTID
            );
            return;
        } else if (_lootBoxType == 2) {
            require(
                address(capxToken) != address(0),
                "CapxRedemption: Token contract not set"
            );

            require(
                lootBoxMinted.capxTokens + 1 <= maxCapxTokensLootboxes,
                "CapxRedemption: Max cap for redeeming Capx Tokens has reached."
            );

            require(IERC20(capxToken).approve(_msgSender(), _capxTokenAmount));

            lootBoxMinted.capxTokens += 1;

            uint256 TokensRedeemedLootboxID = capxGameResource.burnLootbox(
                _msgSender()
            );

            IERC20(capxToken).safeTransfer(_msgSender(), _capxTokenAmount);

            emit CapxLootBoxRedeemedTokens(
                _msgSender(),
                TokensRedeemedLootboxID,
                _capxTokenAmount
            );
            return;
        } else if (_lootBoxType == 3) {
            require(
                address(capxGameResource) != address(0),
                "CapxRedemption: Game Resource contract not set"
            );

            require(
                lootBoxMinted.resources + 1 <= maxResourcesLootboxes,
                "CapxRedemption: Max cap for redeeming resources has reached."
            );

            lootBoxMinted.resources += 1;

            uint256 resourcesRedeemedLootBoxID = capxGameResource.burnLootbox(
                _msgSender()
            );

            capxGameResource.redeemResources(
                _msgSender(),
                _resources,
                _amounts
            );

            emit CapxLootBoxRedeemedResource(
                _msgSender(),
                resourcesRedeemedLootBoxID,
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
        uint256 _maxLootboxes = maxResourcesLootboxes +
            maxCapxTokensLootboxes +
            maxNFTLootboxes;
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

    function updateMaxCapxTokensLootboxes(uint256 _maxCapxTokensLootboxes)
        external
        onlyOwner
    {
        require(
            _maxCapxTokensLootboxes > 0,
            "CapxRedemption: Max Capx tokens lootboxes cannot be less than 0"
        );
        maxCapxTokensLootboxes = _maxCapxTokensLootboxes;
    }
}
