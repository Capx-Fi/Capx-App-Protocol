// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CapxNFT is ERC721, Ownable, Pausable, ERC721Enumerable {
    using Strings for uint256;

    string public baseURI;
    address public authorizedMinter;
    uint256 public maxSupply = 10000;

    mapping(address => bool) public whitelist;

    modifier onlyAuthorized() {
        require(
            owner() == _msgSender() || authorizedMinter == _msgSender(),
            "CapxNFT: Caller NOT Authorized."
        );
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _authorizedMinter
    ) ERC721(_name, _symbol) {
        require(
            _authorizedMinter != address(0),
            "CapxNFT: ZeroAddress NOT Allowed"
        );
        authorizedMinter = _authorizedMinter;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external virtual whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external virtual whenPaused onlyOwner {
        _unpause();
    }

    function mint(address player) external onlyAuthorized returns (uint256) {
        require(
            totalSupply() < maxSupply,
            "CapxNFT: Cannot mint NFT, reached maxSupply"
        );
        uint256 tokenId = totalSupply() + 1;

        _safeMint(player, tokenId);

        return tokenId;
    }

    function burn(uint256 _tokenId) external onlyAuthorized {
        require(_exists(_tokenId), "CapxNFT: Token does not exist");
        _burn(_tokenId);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(_tokenId), "CapxNFT: Token does not exist");
        return string(abi.encodePacked(baseURI, _tokenId.toString(), ".json"));
    }

    function updateAuthorizedMinter(address _authorizedMinter)
        external
        onlyOwner
    {
        authorizedMinter = _authorizedMinter;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return
            _interfaceId == type(IERC721).interfaceId ||
            _interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    function _exists(uint256 _tokenId) internal view virtual returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    function _increaseBalance(address _account, uint128 _amount)
        internal
        virtual
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(_account, _amount);
    }
    
    function _update(
        address _to,
        uint256 _tokenId,
        address _auth
    ) internal virtual override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(_to, _tokenId, _auth);
    }

    function increaseMaxSupply(uint256 _maxSupply) external onlyOwner {
        maxSupply = _maxSupply;
    }

    function updateOwner(address _newOwner) external onlyOwner {
        require(
            _newOwner != address(0),
            "CapxNFT: new owner is the zero address"
        );

        transferOwnership(_newOwner);
    }
}
