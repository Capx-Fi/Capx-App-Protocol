//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

abstract contract IOUToken {
    function initialize (
        string memory name_, 
        string memory symbol_,
        address owner_,
        address capxQuestForger_,
        uint256 totalCappedSupply_
    ) public virtual;
}

contract CapxIOUForger is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {

    address public capxIOUToken;
    address public capxQuestForger;
    mapping(address => bool) public capxIOUTokens;

    event NewCapxIOUToken (
        address indexed capxIOUToken,
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
        require(_address != address(0), "CapxIOUForger: Invalid address");
        require(_address == address(_address), "CapxIOUForger: Invalid address");
        _;
    }

    function initialize(
        address _capxIOUToken
    ) external checkIsAddressValid(_capxIOUToken) initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _transferOwnership(_msgSender());

        capxIOUToken = _capxIOUToken;
    }

    /// @notice function to Pause smart contract.
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @notice function to UnPause smart contract
    function unPause() public onlyOwner whenPaused {
        _unpause();
    }

    function updateCapxIOUToken(
        address _capxIOUToken
    ) external onlyOwner checkIsAddressValid(_capxIOUToken) whenNotPaused {
        capxIOUToken = _capxIOUToken;
    }

    function updateCapxQuestForger(
        address _capxQuestForger
    ) external onlyOwner checkIsAddressValid(_capxQuestForger) whenNotPaused {
        capxQuestForger = _capxQuestForger;
    }

    function createIOUToken(
        string memory name,
        string memory symbol,
        address _owner,
        uint256 totalCappedSupplyInWei
    ) external onlyOwner checkIsAddressValid(_owner) nonReentrant() whenNotPaused virtual returns(address iouToken) {
        require(capxQuestForger != address(0),"CapxQuestForger NOT configured.");
        require(totalCappedSupplyInWei != 0,"Token's Maximum Capped Supply cannot be ZERO");
        iouToken = Clones.clone(capxIOUToken);
        capxIOUTokens[iouToken] = true;

        emit NewCapxIOUToken (
            iouToken,
            _owner,
            name,
            symbol,
            totalCappedSupplyInWei
        );

        IOUToken(iouToken).initialize(
            name,
            symbol,
            _owner,
            capxQuestForger,
            totalCappedSupplyInWei
        );
    }

    function isCapxIOUToken(address iouToken) external view returns(bool) {
        return capxIOUTokens[iouToken];
    }

}