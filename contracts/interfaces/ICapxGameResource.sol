// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxGameResource {
    // Constants
    function FIRE() external view returns (uint256);
    function WATER() external view returns (uint256);
    function AIR() external view returns (uint256);
    function EARTH() external view returns (uint256);
    function LOOTBOX() external view returns (uint256);
    function MAX_LOOTBOXES() external view returns (uint256);
    function MAX_RESOURCES_PER_MINT() external view returns (uint256);

    // State Variables
    function lastMinedTimestamp(address) external view returns (uint256);
    function lootBoxMinted() external view returns (uint256);
    function lootBoxIDs(address) external view returns (uint256[] memory);
    function userRedeemedLootBox(address) external view returns (uint256);
    function authorizedMinter() external view returns (address);
    function baseURI() external view returns (string memory);

    // Events
    event CapxResourcesMinted(address player, uint256[] resources, uint256[] amounts, uint256 minedTimestamp);
    event CapxLootboxForged(address player, uint256 lootboxID);

    // Functions
    function mintResources(address player, uint256[] calldata resources, uint256[] calldata amounts, uint256 mineTimeStamp) external;
    function craftLootbox(address player) external;
    function redeemResources(address player, uint256[] calldata resources, uint256[] calldata amounts) external;
    function uri(uint256 _tokenid) external view returns (string memory);
    function burnLootbox(address player) external returns (uint256);
}
