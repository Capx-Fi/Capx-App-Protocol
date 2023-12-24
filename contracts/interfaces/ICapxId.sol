// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxID {
    struct CapxIDMetadata {
        string username;
        uint256 mintID;
        uint256 reputationScore;
    }

    function capxIDMetadata(address user)
        external
        view
        returns (CapxIDMetadata memory);

    function updateReputationScore(uint256 tokenId, uint256 reputationScore)
        external;

    function getCapxIDMetadata(string calldata _username)
        external
        view
        returns (CapxIDMetadata memory);

    function capxID(string calldata username) external view returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);
}
