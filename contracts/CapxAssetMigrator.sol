//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CapxAssetMigrator is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    error ZeroAddressNotAllowed();

    event Migrated(
        address fromAddress,
        address toAddress,
        address biconomyAddress,
        address[] tokenAddresses
    );

    address public authorizedSigner;
    
    mapping(address => address) public migratedAddress;

    constructor() initializer {}

    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    function initialize(
        address _authorizedSigner
    ) external initializer {
        if (_authorizedSigner == address(0)) revert ZeroAddressNotAllowed();
        
        __Context_init();
        __Ownable_init();
        authorizedSigner = _authorizedSigner;
    }

    /// @notice function to Pause smart contract.
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @notice function to UnPause smart contract
    function unPause() public onlyOwner whenPaused {
        _unpause();
    }

    function setAuthorizedSignerAddress(address _authorizedSigner) public onlyOwner {
        if (_authorizedSigner == address(0)) revert ZeroAddressNotAllowed();
        authorizedSigner = _authorizedSigner;
    }

    function recoverSigner(bytes32 messagehash, bytes memory signature) public pure returns (address) {
        bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messagehash));
        return ECDSAUpgradeable.recover(messageDigest, signature);
    }

    function migrate(
        bytes32 _messageHash,
        bytes memory _signature,
        address _fromAddress,
        address _toAddress,
        address _biconomyAddress,
        address[] memory _tokenList
    ) external whenNotPaused {
        require(keccak256(abi.encodePacked(_fromAddress,_toAddress, _biconomyAddress,_tokenList)) == _messageHash, "MigrationError: Invalid MessageHash");
        require(recoverSigner(_messageHash, _signature) == authorizedSigner, "MigrationError: Invalid Signer");

        for(uint256 i = 0; i < _tokenList.length; i++) {
            if (address(_tokenList[i]) == address(0)) revert ZeroAddressNotAllowed();
            uint256 tokenBalance = IERC20(_tokenList[i]).balanceOf(_fromAddress);
            IERC20(_tokenList[i]).safeTransferFrom(_fromAddress, address(this), tokenBalance);
            IERC20(_tokenList[i]).safeTransfer(_toAddress, tokenBalance);
        }
        
        migratedAddress[_fromAddress] = _toAddress;
        emit Migrated(
            _fromAddress,
            _toAddress,
            _biconomyAddress,
            _tokenList
        );
    }
}
