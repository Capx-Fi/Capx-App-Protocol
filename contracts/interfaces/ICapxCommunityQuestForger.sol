//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18 .0;

interface ICapxCommunityQuestForger {
    error ZeroAddressNotAllowed();
    error QuestNotActive();
    error QuestIdUsed();
    error OwnerOwnsACommunity();
    error InvalidMessageHash();
    error InvalidSigner();
    error InvalidRewardType();
    error NotAuthorized();
    error CommunityAlreadyExists();
    error InvalidCommunityId();
    error InvalidCommunityAddress();
    error NotCapxGeneratedToken();
    error RewardTypeMismatch();
    error InvalidQuestNumber();
    error InvalidStartTime();
    error InvalidEndTime();
    error QuestNotStarted();
    error QuestEnded();
    error OverMaxParticipants();
    error CapxReputationContractNotInitalised();
    error QuestIdDoesNotExist();
    error QuestAlreadyActive();
    error QuestAlreadyDisabled();
    error CommunityOwnerCannotBeRemoved();
    error InvalidAuthorizedAccount();
    error AccountBelongsToAuthorizedCommunity();
    error AccountBelongsToDifferentCommunity();
    error AlreadyAuthorized();
    error AlreadyNotAuthorized();
    error UseRewardTypeSpecificFunctions();
    error InvalidIOURewards();

    event CapxCommunityQuestCreated(
        address indexed creator,
        string questId,
        address rewardToken,
        uint256 maxParticipants,
        uint256 totalRewardAmountInWei,
        uint256 maxRewardAmountInWei
    );

    event CapxCommunityQuestRewardClaimed(
        address indexed communityAddress,
        string questId,
        address claimReceiver,
        uint256 timestamp,
        address rewardToken,
        uint256 rewardAmount
    );

    event CapxReputationScoreClaimed(
        address indexed communityAddress,
        string questId,
        address claimReceiver,
        uint256 timestamp,
        uint256 reputationType,
        uint256 reputationScore
    );

    function claimSignerAddress() external view returns (address);

    function updateCommunityOwner(address _oldOwner, address _newOwner)
        external;
}
