//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

abstract contract IOUToken {
    function initialize (
        string memory name_, 
        string memory symbol_,
        address owner_
    ) public virtual;
}

contract CapxIOUForger is Initializable, UUPSUpgradeable, OwnableUpgradeable {

    address public capxIOUToken;
    mapping(address => bool) public capxIOUTokens;

    event NewCapxIOUToken (
        address indexed capxIOUToken,
        address indexed owner,
        string name,
        string symbol
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
        _transferOwnership(_msgSender());

        capxIOUToken = _capxIOUToken;
    }

    function createIOUToken(
        string memory name,
        string memory symbol,
        address _owner
    ) external checkIsAddressValid(_owner) virtual returns(address iouToken) {
        iouToken = Clones.clone(capxIOUToken);
        capxIOUTokens[iouToken] = true;

        emit NewCapxIOUToken (
            iouToken,
            _owner,
            name,
            symbol
        );

        IOUToken(iouToken).initialize(
            name,
            symbol,
            _owner
        );
    }

    function isCapxIOUToken(address iouToken) external view returns(bool) {
        return capxIOUTokens[iouToken];
    }

}