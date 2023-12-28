//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18 .0;

interface ICapxReputationScore {
    error ZeroAddressNotAllowed();
    error RewardTypeNotInitialised();
    error NotAuthorized();
    error ForgerNotInitialised();
    error MaxRewardExceeded();
    error ReputationTypeMisMatch();
    error InvalidReputationType();
    error capxIdNotMinted();
    error questIdNotCreated();
    error InvalidMaxReputationScore();

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

    function setQuestDetails(QuestDTO memory quest) external;
}
