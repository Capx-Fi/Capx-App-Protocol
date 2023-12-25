//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxCommunityQuestForger {
    error ZeroAddressNotAllowed();
    error QuestNotActive();
    error QuestIdUsed();
    error OwnerOwnsACommunity();
    error InvalidMessageHash();
    error InvalidSigner();
    error InvalidRewardType();

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
        string questId,
        address claimReceiver,
        uint256 timestamp,
        uint256 reputationType,
        uint256 reputationScore
    );

    function emitClaim(
        address communityAddress,
        string memory questId,
        address claimReceiver,
        uint256 timestamp,
        address rewardToken,
        uint256 rewardAmount
    ) external;

    function claimSignerAddress() external view returns (address);

    function updateCommunityOwner(address _oldOwner, address _newOwner)
        external;
}
