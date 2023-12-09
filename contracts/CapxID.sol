// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CapxID is ERC721, Ownable, Pausable, ERC721Enumerable {
    using Strings for uint256;

    struct CapxIDMetadata {
        string username;
        uint256 mintID;
        uint256 reputationScore;
    }

    event CapxIDMint(
        address user,
        string username,
        uint256 mintID
    );

    string public baseURI;
    bool private revealURI;
    address public authorizedMinter;
    uint256 public REPUTATION_SCORE;

    mapping(address => CapxIDMetadata) public capxIDMetadata;
    mapping(string => uint256) public capxID;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public authorized;
    mapping(uint256 => string) private tokenURIs; 

    modifier onlyWhitelisted(address sender, address recipient) {
        require(owner() == _msgSender() || whitelist[sender] || whitelist[recipient], "CapxID: neither sender nor recipient is whitelisted");
        _;
    }

    modifier onlyAuthorized() {
        require(owner() == _msgSender() || authorized[_msgSender()],"CapxID: Caller NOT Authorized.");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _authorizedMinter
    ) ERC721(_name, _symbol) {
        require(_authorizedMinter != address(0),"CapxID: ZeroAddress NOT Allowed");
        REPUTATION_SCORE = 69;
        authorizedMinter = _authorizedMinter;
    }

    function recoverSigner(bytes32 messagehash, bytes memory signature) internal pure returns (address) {
        bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messagehash));
        return ECDSA.recover(messageDigest, signature);
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

    function mint(
        bytes32 _messageHash,
        bytes memory _signature,
        string memory _username,
        string memory _tokenURI
    ) external {
        require(capxID[_username] == 0, "CapxID: Username has already minted");
        CapxIDMetadata storage _metadata = capxIDMetadata[_msgSender()];
        require(_metadata.mintID == 0, "CapxID: User has already minted");
        require(keccak256(abi.encodePacked(_username,_tokenURI)) == _messageHash, "CapxID: Invalid MessageHash");
        require(recoverSigner(_messageHash, _signature) == authorizedMinter,"CapxID: Invalid Minter");
        uint256 tokenId = totalSupply() + 1;
        _metadata.mintID = tokenId;
        _metadata.reputationScore = REPUTATION_SCORE;
        _metadata.username = _username;
        tokenURIs[tokenId] = _tokenURI;
        capxID[_username] = tokenId;

        _safeMint(_msgSender(), tokenId);

        emit CapxIDMint(
            _msgSender(),
            _username,
            tokenId
        );
    }

    function adminMint(
        address _holder,
        string memory _username,
        string memory _tokenURI
    ) external onlyOwner {
        require(capxID[_username] == 0, "CapxID: Username has already minted");
        CapxIDMetadata storage _metadata = capxIDMetadata[_holder];
        require(_metadata.mintID == 0, "CapxID: User has already minted");
        uint256 tokenId = totalSupply() + 1;
        _metadata.mintID = tokenId;
        _metadata.reputationScore = REPUTATION_SCORE;
        _metadata.username = _username;
        tokenURIs[tokenId] = _tokenURI;
        capxID[_username] = tokenId;

        _safeMint(_holder, tokenId);

        emit CapxIDMint(
            _holder,
            _username,
            tokenId
        );
    }

    function burn(
        uint256 _tokenId
    ) external onlyAuthorized {
        require(_exists(_tokenId), "CapxID: Token does not exist");
        CapxIDMetadata storage _metadata = capxIDMetadata[_ownerOf(_tokenId)];
        _metadata.mintID = 0;
        _metadata.username = "";
        _metadata.reputationScore = 0;
        tokenURIs[_tokenId] = "";
        _burn(_tokenId);
    }

    /**
    * @dev Add `account` to the `whitelist` list.
    *
    */
    function addToWhitelist(address account) external onlyAuthorized {
        whitelist[account] = true;
    }

    /**
    * @dev Remove `account` from the `whitelist` list.
    *
    */
    function removeFromWhitelist(address account) external onlyAuthorized {
        whitelist[account] = false;
    }

    /**
    * @dev Add `account` to the `authorized` list.
    *
    */
    function addToAuthorized(address account) external onlyOwner {
        authorized[account] = true;
    }

    /**
    * @dev Remove `account` from the `authorized` list.
    *
    */
    function removeFromAuthorized(address account) external onlyOwner {
        authorized[account] = false;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function toggleURI() external onlyAuthorized {
        revealURI = !revealURI;
    }

    function updateTokenURI(uint256 _tokenId, string memory _tokenURI) public onlyAuthorized {
        require(_exists(_tokenId), "CapxID: Token does not exist");
        tokenURIs[_tokenId] = _tokenURI;
    }

    function updateReputationScore(uint256 _tokenId, uint256 _reputationScore) public onlyAuthorized {
        require(_exists(_tokenId), "CapxID: Token does not exist");
        CapxIDMetadata storage _metadata = capxIDMetadata[_ownerOf(_tokenId)];
        _metadata.reputationScore = _reputationScore;
    }

    function updateUsername(uint256 _tokenId, string memory _username) public onlyAuthorized {
        require(_exists(_tokenId), "CapxID: Token does not exist");
        CapxIDMetadata storage _metadata = capxIDMetadata[_ownerOf(_tokenId)];
        _metadata.username = _username;
    }

    function configReputationScore(uint256 _reputationScore) public onlyOwner {
        REPUTATION_SCORE = _reputationScore;
    }

    function setAuthorizedMinterAddress(address _authorizedMinter) public onlyOwner {
        require(_authorizedMinter != address(0),"CapxID: ZeroAddress NOT Allowed");
        authorizedMinter = _authorizedMinter;
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

    function _increaseBalance(address _account, uint128 _amount) internal virtual override(ERC721,ERC721Enumerable) {
        super._increaseBalance(_account, _amount);
    }

    function _update(address _to, uint256 _tokenId, address _auth) internal virtual override(ERC721,ERC721Enumerable) returns (address) {
        return super._update(_to, _tokenId, _auth);
    }

    function _exists(uint256 _tokenId) internal view virtual returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "");
        if (revealURI) {
            return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenURIs[_tokenId], ".json")) : "";
        }
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, "default.json")) : "";
    }

    function transferFrom(address _from, address _to, uint256 _tokenId)
        public
        virtual
        override(ERC721, IERC721)
        onlyWhitelisted(_from,_to)
    {
        super.transferFrom(_from,_to, _tokenId);
    }

    function getCapxIDMetadata(string calldata _username) public view returns(CapxIDMetadata memory) {
        uint256 tokenID = capxID[_username];
        address tokenOwner = ownerOf(tokenID);
        return capxIDMetadata[tokenOwner];
    }
}