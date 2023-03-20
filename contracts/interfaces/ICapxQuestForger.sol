//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface ICapxQuestForger {

    error QuestIdUsed();
    error RewardNotAllowed();
    error QuestRewardTypeInvalid();
    error ZeroAddressNotAllowed();
    error QuestNotStarted();
    error QuestNotActive();
    error QuestEnded();

    event CapxQuestCreated(
        address indexed creator,
        address indexed questAddress,
        string questId,
        string questRewardType,
        address rewardToken,
        uint256 startTime,
        uint256 endTime,
        uint256 maxParticipants,
        uint256 rewardAmountInWei
    );

    event CapxQuestRewardClaimed(
        address indexed questAddress,
        string questId,
        address claimer,
        address rewardToken,
        uint256 rewardAmount
    );

    function questInfo(string memory _questId) external view returns (address, uint, uint);
    function getClaimedNumber(string memory _questId) external view returns(uint);
}