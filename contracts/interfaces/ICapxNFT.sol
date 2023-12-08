// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxNFT {
    // Public state variables
    function baseURI() external view returns (string memory);
    function authorizedMinter() external view returns (address);
    function maxSupply() external view returns (uint256);

    // Events
    event CapxNFTMint(address indexed user, uint256 mintID);

    // Functions
    function pause() external;
    function unpause() external;
    function mint(address player) external returns (uint256);
    function burn(uint256 _tokenId) external;
    function tokenURI(uint256 _tokenId) external view returns (string memory);
    function addToWhitelist(address account) external;
    function removeFromWhitelist(address account) external;
    function setBaseURI(string memory _newBaseURI) external;
    function supportsInterface(bytes4 _interfaceId) external view returns (bool);
    function transferFrom(address _from, address _to, uint256 _tokenId) external;
    function increaseMaxSupply(uint256 _maxSupply) external;
    function updateOwner(address _newOwner) external;
    function updateAuthorizedMinter(address _authorizedMinter) external;
}
