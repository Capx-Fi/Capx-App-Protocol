// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {ICapxID} from "./interfaces/ICapxId.sol";
import {ICapxReputationScore} from "./interfaces/ICapxReputationScore.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ReputationContract is
    Ownable,
    ReentrancyGuard,
    Pausable,
    ICapxReputationScore
{
    ICapxID public capxID;

    address public forgerContract;

    mapping(address => ReputationScoreTypes) public reputationScore;
    mapping(string => mapping(address => mapping(uint256 => bool)))
        private claimedUsers;
    mapping(string => CapxQuestDetails) public communityQuestDetails;

    modifier onlyForger() {
        if (forgerContract == address(0)) revert ForgerNotInitialised();
        if (_msgSender() != forgerContract) revert NotAuthorized();
        _;
    }

    constructor(address _capxId) {
        capxID = ICapxID(_capxId);
    }

    function setQuestDetails(QuestDTO memory quest) external onlyForger {
        if (quest.reputationType < 1 || quest.reputationType > 3)
            revert InvalidReputationType();
        if (quest.maxReputationScore <= 0) revert InvalidMaxReputationScore();

        // For handling case : reward type 2->3 or 3->2
        // If the old reputationType and the new reputationType are same then retain the claimedUsers and claimedReputationScore.
        if (
            communityQuestDetails[quest.communityQuestId].reputationType ==
            quest.reputationType
        ) {
            communityQuestDetails[quest.communityQuestId] = CapxQuestDetails({
                reputationType: quest.reputationType,
                maxReputationScore: quest.maxReputationScore,
                claimedUsers: communityQuestDetails[quest.communityQuestId]
                    .claimedUsers,
                claimedReputationScore: communityQuestDetails[
                    quest.communityQuestId
                ].claimedReputationScore
            });
        } else {
            // Incase they change the reputationType, claimedUsers and claimedReputationScore turns to 0.
            communityQuestDetails[quest.communityQuestId] = CapxQuestDetails({
                reputationType: quest.reputationType,
                maxReputationScore: quest.maxReputationScore,
                claimedUsers: 0,
                claimedReputationScore: 0
            });
        }
    }

    function disableQuest(string memory _communityQuestId) external onlyForger {
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _communityQuestId
        ];

        if (
            currCapxQuest.reputationType == 0 ||
            currCapxQuest.maxReputationScore == 0
        ) revert RewardTypeNotInitialised();

        currCapxQuest.reputationType = 0;
        currCapxQuest.maxReputationScore = 0;
    }

    // Function to claim reputation scores
    function claim(
        string memory _communityQuestId,
        uint256 _timestamp,
        uint256 _reputationType,
        uint256 _reputationScore,
        address _receiver
    ) external onlyForger nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert ZeroAddressNotAllowed();

        if (claimedUsers[_communityQuestId][_receiver][_timestamp] == true)
            revert AlreadyClaimed();

        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _communityQuestId
        ];

        if (
            currCapxQuest.reputationType == 0 ||
            currCapxQuest.maxReputationScore == 0
        ) revert RewardTypeNotInitialised();

        if (currCapxQuest.maxReputationScore < _reputationScore)
            revert MaxRewardExceeded();

        if (currCapxQuest.reputationType != _reputationType)
            revert ReputationTypeMisMatch();

        claimedUsers[_communityQuestId][_receiver][_timestamp] = true;

        (, uint256 capxIdMintId, uint256 capxIdReputationScore) = capxID
            .capxIDMetadata(_receiver);

        if (_reputationType == 1) {
            reputationScore[_receiver].social += _reputationScore;
        } else if (_reputationType == 2) {
            reputationScore[_receiver].defi += _reputationScore;
        } else if (_reputationType == 3) {
            reputationScore[_receiver].game += _reputationScore;
        } else {
            revert InvalidReputationType();
        }

        uint256 updatedReputationScore = capxIdReputationScore +
            _reputationScore;

        currCapxQuest.claimedUsers += 1;
        currCapxQuest.claimedReputationScore += _reputationScore;

        capxID.updateReputationScore(capxIdMintId, updatedReputationScore);
    }

    function updateReputationScore(
        uint256 _reputationType,
        uint256 _reputationScore,
        address _receiver
    ) external onlyForger nonReentrant whenNotPaused {
        if (_receiver == address(0)) revert ZeroAddressNotAllowed();

        if (_reputationType == 1) {
            reputationScore[_receiver].social = _reputationScore;
        } else if (_reputationType == 2) {
            reputationScore[_receiver].defi = _reputationScore;
        } else if (_reputationType == 3) {
            reputationScore[_receiver].game = _reputationScore;
        } else {
            revert InvalidReputationType();
        }
    }

    function getCapxIDMetadata(
        string calldata username
    ) public view returns (CapxReputationMetadata memory) {
        ICapxID.CapxIDMetadata memory capxIdMetadata = capxID.getCapxIDMetadata(
            username
        );

        if (capxIdMetadata.mintID == 0) revert CapxIdNotMinted();

        address tokenOwner = capxID.ownerOf(capxIdMetadata.mintID);

        CapxReputationMetadata memory repMetadata = CapxReputationMetadata({
            username: username,
            mintID: capxIdMetadata.mintID,
            socialScore: reputationScore[tokenOwner].social,
            defiScore: reputationScore[tokenOwner].defi,
            gameScore: reputationScore[tokenOwner].game
        });
        return repMetadata;
    }

    function pause() external virtual whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() external virtual whenPaused onlyOwner {
        _unpause();
    }

    function setForgerContract(address _forgerContract) external onlyOwner {
        if (_forgerContract == address(0)) revert ZeroAddressNotAllowed();
        forgerContract = _forgerContract;
    }
}
