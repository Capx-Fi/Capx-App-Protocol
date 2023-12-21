// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxGameResource {
    function mineResource(address player, uint256 resource, uint256 amount, uint256 mineTimeStamp) external;
    function forgeLootbox(address player) external;
    function mintLootbox(address player, uint256 lootboxId) external;
    function redeemResources(address player, uint256[] calldata resources, uint256[] calldata amounts) external;
    function burnLootbox(address player) external returns (uint256);
}
