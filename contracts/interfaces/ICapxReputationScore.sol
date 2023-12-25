//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxReputationScore {
    function claim(
        string memory _communityQuestId,
        uint256 _timestamp,
        uint256 _reputationType,
        uint256 _reputationScore,
        address _receiver
    ) external;
}
