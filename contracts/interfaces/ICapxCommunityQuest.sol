//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18 .0;

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
    error NotAuthorized();
    error CannotClaimFutureReward();
    error NoRewardsToWithdraw();
    error ClaimedRewardsExceedTotalRewards();
    error AlreadyUnauthorized();
    error AlreadyAuthorized();
    error QuestAlreadyActive();
    error QuestAlreadyDisabled();
    error InvalidIOURewards();

    struct QuestDTO {
        uint256 questNumber;
        address rewardToken;
        uint256 totalRewardAmountInWei;
        uint256 maxRewardAmountInWei;
        address caller;
    }

    function claim(
        string memory _questId,
        address _receiver,
        uint256 _timestamp,
        uint256 _rewardAmount
    ) external returns (address);

    function updateTotalRewards(
        address caller,
        uint256 _questNumber,
        uint256 _rewardAmount,
        bool _maxParticipantsIncreased
    ) external;

    function setQuestDetails(QuestDTO memory quest) external;
    function enableQuest(uint256 _questNumber) external;
    function disableQuest(uint256 _questNumber) external;
    function withdrawTokens(address[] memory tokens) external;

}
