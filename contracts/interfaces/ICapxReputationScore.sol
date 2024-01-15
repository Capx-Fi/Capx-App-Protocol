//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface ICapxReputationScore {
    error ZeroAddressNotAllowed();
    error RewardTypeNotInitialised();
    error NotAuthorized();
    error ForgerNotInitialised();
    error MaxRewardExceeded();
    error ReputationTypeMisMatch();
    error InvalidReputationType();
    error CapxIdNotMinted();
    error InvalidMaxReputationScore();
    error AlreadyClaimed();

    struct CapxReputationMetadata {
        string username;
        uint256 mintID;
        uint256 socialScore;
        uint256 defiScore;
        uint256 gameScore;
    }

    // 1. Social 2. Defi 3. Game
    struct ReputationScoreTypes {
        uint256 social;
        uint256 defi;
        uint256 game;
    }

    struct ReputationClaimDetails {
        uint256 claimedUsers;
        uint256 claimedReputationScore;
    }

    struct CapxQuestDetails {
        uint256 reputationType;
        uint256 maxReputationScore;
        mapping(uint256 => ReputationClaimDetails) reputationClaims; // Key: Reputation Type
    }

    struct QuestDTO {
        string communityQuestId;
        uint256 reputationType;
        uint256 maxReputationScore;
    }

    function claim(
        string memory _communityQuestId,
        uint256 _timestamp,
        uint256 _reputationType,
        uint256 _reputationScore,
        address _receiver
    ) external;

    function disableQuest(string memory _communityQuestId) external;

    function setQuestDetails(QuestDTO memory quest) external;
}
