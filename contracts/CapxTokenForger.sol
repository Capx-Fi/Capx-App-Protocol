//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

abstract contract TokenPoweredByCapx {
    function initialize (
        string memory name_, 
        string memory symbol_,
        address owner_,
        address capxQuestForger_,
        uint256 totalCappedSupply_
    ) public virtual;
}

contract CapxTokenForger is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {

    address public tokenPoweredByCapx;
    address public capxQuestForger;
    mapping(address => bool) public tokensPoweredByCapx;

    event NewTokenPoweredByCapx (
        address indexed tokenPoweredByCapx,
        address indexed owner,
        string name,
        string symbol,
        uint256 maxTotalSupply
    );

    constructor() initializer {}

    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    modifier checkIsAddressValid(address _address)
    {
        require(_address != address(0), "CapxTokenForger: Invalid address");
        require(_address == address(_address), "CapxTokenForger: Invalid address");
        _;
    }

    function initialize(
        address _tokenPoweredByCapx
    ) external checkIsAddressValid(_tokenPoweredByCapx) initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _transferOwnership(_msgSender());

        tokenPoweredByCapx = _tokenPoweredByCapx;
    }

    /// @notice function to Pause smart contract.
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @notice function to UnPause smart contract
    function unPause() public onlyOwner whenPaused {
        _unpause();
    }

    function updateTokenPoweredByCapx(
        address _tokenPoweredByCapx
    ) external onlyOwner checkIsAddressValid(_tokenPoweredByCapx) whenNotPaused {
        tokenPoweredByCapx = _tokenPoweredByCapx;
    }

    function updateCapxQuestForger(
        address _capxQuestForger
    ) external onlyOwner checkIsAddressValid(_capxQuestForger) whenNotPaused {
        capxQuestForger = _capxQuestForger;
    }

    function createTokenPoweredByCapx(
        string memory name,
        string memory symbol,
        address _owner,
        uint256 totalCappedSupplyInWei
    ) external onlyOwner checkIsAddressValid(_owner) nonReentrant() whenNotPaused virtual returns(address _tokenPoweredByCapx) {
        require(capxQuestForger != address(0),"CapxQuestForger NOT configured.");
        require(totalCappedSupplyInWei != 0,"Token's Maximum Capped Supply cannot be ZERO");
        _tokenPoweredByCapx = Clones.clone(tokenPoweredByCapx);
        tokensPoweredByCapx[_tokenPoweredByCapx] = true;

        emit NewTokenPoweredByCapx (
            _tokenPoweredByCapx,
            _owner,
            name,
            symbol,
            totalCappedSupplyInWei
        );

        TokenPoweredByCapx(_tokenPoweredByCapx).initialize(
            name,
            symbol,
            _owner,
            capxQuestForger,
            totalCappedSupplyInWei
        );
    }

    function isTokenPoweredByCapx(address _tokenPoweredByCapx) external view returns(bool) {
        return tokensPoweredByCapx[_tokenPoweredByCapx];
    }

}