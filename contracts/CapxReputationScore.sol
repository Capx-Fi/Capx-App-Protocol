// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {ICapxID} from "./interfaces/ICapxId.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract ReputationContract is Ownable, ReentrancyGuard, Pausable {
    ICapxID capxID;

    // Scores for different categories
    struct reputationScoreTypes {
        uint256 social;
        uint256 defi;
        uint256 game;
    }

    struct CapxReputationMetadata {
        string username;
        uint256 mintID;
        uint256 socialScore;
        uint256 defiScore;
        uint256 gameScore;
    }

    event CapxReputationScore(
        address user,
        string username,
        uint256 reputationType,
        uint256 reputationScore
    );

    address public authorizedMinter;

    mapping(address => reputationScoreTypes) public reputationScore;

    // Modifier to restrict function access to only the authorizedMinter
    modifier onlyAuthorized() {
        require(
            msg.sender == authorizedMinter || msg.sender == owner(),
            "CapxReputation: Caller is not authorized"
        );
        _;
    }

    // Constructor to set the initial authorizedMinter
    constructor(address _authorizedMinter, address _capxId) {
        authorizedMinter = _authorizedMinter;
        capxID = ICapxID(_capxId);
    }

    // Function to claim reputation scores
    function claimReputationScore(
        uint256 _reputationType,
        uint256 _reputationScore,
        address _receiver
    ) external onlyAuthorized nonReentrant whenNotPaused {
        require(
            _receiver != address(0),
            "CapxReputation: Invalid receiver address"
        );

        ICapxID.CapxIDMetadata memory metadata = capxID.capxIDMetadata(
            _receiver
        );

        if (_reputationType == 1) {
            reputationScore[_receiver].social += _reputationScore;
        } else if (_reputationType == 2) {
            reputationScore[_receiver].defi += _reputationScore;
        } else if (_reputationType == 3) {
            reputationScore[_receiver].game += _reputationScore;
        } else {
            revert("CapxReputation: Invalid reputation type");
        }

        uint256 updatedReputationScore = metadata.reputationScore +
            _reputationScore;

        capxID.updateReputationScore(metadata.mintID, updatedReputationScore);
    }

    function updateReputationScore(
        uint256 _reputationType,
        uint256 _reputationScore,
        address _receiver
    ) external onlyAuthorized nonReentrant whenNotPaused {
        require(
            _receiver != address(0),
            "CapxReputation: Invalid receiver address"
        );

        if (_reputationType == 1) {
            reputationScore[_receiver].social = _reputationScore;
        } else if (_reputationType == 2) {
            reputationScore[_receiver].defi = _reputationScore;
        } else if (_reputationType == 3) {
            reputationScore[_receiver].game = _reputationScore;
        } else {
            revert("CapxReputation: Invalid reputation type");
        }
    }

    function getCapxIDMetadata(string calldata username)
        public
        view
        returns (CapxReputationMetadata memory)
    {
        ICapxID.CapxIDMetadata memory capxIdMetadata = capxID.getCapxIDMetadata(
            username
        );

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

    function setAuthorizedMinter(address _newMinter) external onlyAuthorized {
        require(_newMinter != address(0), "CapxReputation: Invalid address");
        authorizedMinter = _newMinter;
    }
}
