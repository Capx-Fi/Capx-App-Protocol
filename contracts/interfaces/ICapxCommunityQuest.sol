//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxCommunityQuest {
    error AlreadyClaimed();
    error InvalidEndTime();
    error InvalidStartTime();
    error NoRewardsToClaim();
    error QuestIdUsed();
    error InvalidQuestId();
    error QuestNotStarted();
    error QuestEnded();
    error RewardsExceedAllowedLimit();
    error TotalRewardsExceedsAvailableBalance();
    error QuestNotActive();
    error InvalidSigner();
    error InvalidMessageHash();
    error ZeroAddressNotAllowed();
    error OverMaxParticipants();
    error CommunityNotActive();
    error ClaimedRewardsExceedTotalRewards();

    function claim(
        string memory _questId,
        address _receiver,
        uint256 _timestamp,
        uint256 _rewardAmount
    ) external;
}
