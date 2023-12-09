// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {ICapxGameResource} from "contracts/interfaces/ICapxGameResource.sol";
import {ICapxNFT} from "contracts/interfaces/ICapxNFT.sol";

contract CapxGameResourceRedeemer is Ownable, Pausable, ReentrancyGuard {
    ICapxGameResource public capxGameResource;
    ICapxNFT public capxNFT;

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

    constructor(address _authorizedSigner) {
        authorizedSigner = _authorizedSigner;
    }

    function updateGameResourceContractAddress(address _capxGameResource)
        external
        onlyOwner
    {
        capxGameResource = ICapxGameResource(_capxGameResource);
    }

    function updateNFTContractAddress(address _capxNFT) external onlyOwner {
        capxNFT = ICapxNFT(_capxNFT);
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

    function mintResources(
        bytes32 _messageHash,
        bytes memory _signature,
        uint256[] memory resources,
        uint256[] memory amounts,
        uint256 mineTimeStamp
    ) external nonReentrant {
        require(
            address(capxGameResource) != address(0),
            "CapxRedemption: Game resource contract address is not set"
        );
        require(
            keccak256(
                abi.encodePacked(
                    _msgSender(),
                    resources,
                    amounts,
                    mineTimeStamp
                )
            ) == _messageHash,
            "CapxRedemption: Invalid MessageHash"
        );
        require(
            recoverSigner(_messageHash, _signature) == authorizedSigner,
            "CapxRedemption: Invalid Signer"
        );

        capxGameResource.mintResources(
            _msgSender(),
            resources,
            amounts,
            mineTimeStamp
        );
    }

    function craftLootbox() external nonReentrant {
        require(
            address(capxGameResource) != address(0),
            "CapxRedemption: Game resource contract address is not set"
        );
        capxGameResource.craftLootbox(_msgSender());
    }

    function redeemLootbox(
        bytes32 _messageHash,
        bytes memory _signature,
        bytes calldata redemptionData
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
            keccak256(abi.encodePacked(_msgSender(), redemptionData)) ==
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
            bool isNFT
        ) = abi.decode(redemptionData, (uint256[], uint256[], bool));
        
        if (!isNFT) {
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

        uint256 NFTRedeemedLootboxID = capxGameResource.burnLootbox(
            _msgSender()
        );

        uint256 capxNFTID = capxNFT.mint(_msgSender());

        emit CapxLootBoxRedeemedNFT(
            _msgSender(),
            NFTRedeemedLootboxID,
            capxNFTID
        );
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
}
