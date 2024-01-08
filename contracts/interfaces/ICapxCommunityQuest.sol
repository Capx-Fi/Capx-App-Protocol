//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxCommunityQuest {
    error AlreadyClaimed();
    error NoRewardsToClaim();
    error QuestIdUsed();
    error InvalidQuestId();
    error RewardsExceedAllowedLimit();
    error TotalRewardsExceedsAvailableBalance();
    error ZeroAddressNotAllowed();
    error CommunityNotActive();
    error NotAuthorized();
    error CannotClaimFutureReward();
    error NoRewardsToWithdraw();
    error ClaimedRewardsExceedTotalRewards();

    struct CapxQuestDetails {
        address rewardToken;
        uint256 totalRewardAmountInWei;
        uint256 maxRewardAmountInWei;
        uint256 claimedRewards;
        uint256 claimedParticipants;
    }

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

    function updateRewards(
        address caller,
        uint256 _questNumber,
        uint256 totalRewardAmountInWei,
        uint256 maxRewardAmountInWei
    ) external;

    function setQuestDetails(QuestDTO memory quest) external;
    function enableQuest(
        uint256 _questNumber,
        address authorizedCaller
    ) external;
    function disableQuest(uint256 _questNumber) external;
    function withdrawTokens(address[] memory tokens) external;
    function withdrawETH(address caller) external;
}
