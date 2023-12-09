// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxGameResource {
    function mintResources(address player, uint256[] calldata resources, uint256[] calldata amounts, uint256 mineTimeStamp) external;
    function craftLootbox(address player) external;
    function redeemResources(address player, uint256[] calldata resources, uint256[] calldata amounts) external;
    function burnLootbox(address player) external returns (uint256);
}
