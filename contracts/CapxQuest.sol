//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
pragma abicoder v2;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {ICapxQuest} from "./interfaces/ICapxQuest.sol";

interface CapxIQuestForger {
    function emitClaim(
        address questAddress,
        string memory questId,
        address claimer,
        address claimReceiver,
        address rewardToken,
        uint256 rewardAmount
    ) external;

    function claimSignerAddress() external view returns(address);
}

contract CapxQuest is ReentrancyGuard, PausableUpgradeable, OwnableUpgradeable, ICapxQuest {
    using SafeERC20 for IERC20;

    CapxIQuestForger public capxQuestForger;

    string public questId;
    address public rewardToken;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public maxParticipants;
    uint256 public rewardAmountInWei;

    bool public started;
    uint256 public claimedTokenAmt;
    uint256 public participantCount;


    mapping(address => bool) private claimedUsers;

    function questInit(
        address _rewardToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxParticipants,
        uint256 _rewardAmountInWei,
        string memory _questId
    ) public onlyInitializing {
        if (_startTime <= block.timestamp) revert InvalidStartTime();
        if (_endTime <= block.timestamp || _endTime <= _startTime) revert InvalidEndTime();

        startTime = _startTime;
        endTime = _endTime;
        rewardToken = _rewardToken;
        maxParticipants = _maxParticipants;
        rewardAmountInWei = _rewardAmountInWei;
        questId = _questId;
        capxQuestForger = CapxIQuestForger(msg.sender);

        __Ownable_init();
        __Pausable_init();
    }

    function start() public virtual onlyOwner {
        started = true;
        emit Started(block.timestamp);
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unPause() external onlyOwner whenPaused {
        _unpause();
    }

    modifier withdrawAllowed() {
        if (block.timestamp < endTime) revert QuestActiveNoWithdraw();
        _;
    }

    modifier isStarted() {
        if (!started) revert QuestNotStarted();
        _;
    }

    modifier isQuestActive() {
        if (!started) revert QuestNotStarted();
        if (block.timestamp < startTime) revert QuestNotActive();
        _;
    }

    function recoverSigner(bytes32 messagehash, bytes memory signature) public pure returns (address) {
        bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messagehash));
        return ECDSAUpgradeable.recover(messageDigest, signature);
    }

    function claim(
        bytes32 _messageHash,
        bytes memory _signature,
        address _sender,
        address _receiver
    ) external virtual nonReentrant isQuestActive whenNotPaused {
        require(msg.sender == address(capxQuestForger),"NOT Authorized to call.");
        if (participantCount + 1 > maxParticipants) revert OverMaxParticipants();
        if (claimedUsers[_sender] == true) revert AlreadyClaimed();
        if (!started) revert QuestNotStarted();
        if (block.timestamp < startTime) revert QuestNotStarted();
        if (block.timestamp > endTime) revert QuestEnded();
        if (keccak256(abi.encodePacked(_sender,_receiver,questId)) != _messageHash) revert InvalidMessageHash();
        if (recoverSigner(_messageHash, _signature) != capxQuestForger.claimSignerAddress()) revert InvalidSigner();

        claimedUsers[_sender] = true;
        claimedUsers[_receiver] = true;
        ++participantCount;

        uint256 redeemableTokens = _calculateRedeemableTokens();
        uint256 rewards = _calculateRewards(redeemableTokens);
        _transferRewards(_receiver, rewards);

        claimedTokenAmt += rewards;

        capxQuestForger.emitClaim(address(this), questId, _sender, _receiver, rewardToken, rewards);
    }

    function _calculateRedeemableTokens() internal virtual returns (uint256) {
        revert ChildImplementationMissing();
    }

    function _calculateRewards(uint256 _redeemableTokens) internal virtual returns (uint256) {
        revert ChildImplementationMissing();
    }

    function _transferRewards(address _claimer, uint256 _rewardAmount) internal virtual {
        revert ChildImplementationMissing();
    }

    function isClaimed(address _addressInScope) external view returns (bool) {
        return claimedUsers[_addressInScope];
    }

    function getRewardAmount() external view returns (uint256) {
        return rewardAmountInWei;
    }

    function getRewardToken() external view returns (address) {
        return rewardToken;
    }

    function recoverToken(address _tokenAddress) external nonReentrant onlyOwner {
        require(_tokenAddress != rewardToken, "Reward Token Cannot be Recovered");

        uint balance = address(this).balance;
        if (balance > 0) {
            (bool success,) = payable(msg.sender).call{value: balance}("");
            require(success, "Failed to send Ether. Ensure receive() (or) fallback() is implemented");
        }

        uint tokenBalance = IERC20(_tokenAddress).balanceOf(address(this));
        if (tokenBalance > 0) {
            IERC20(_tokenAddress).safeTransfer(msg.sender, tokenBalance);
        }
    }

    function updateRewardAmountInWei(
        uint256 _rewardAmountInWei
    ) external nonReentrant onlyOwner {
        require(_rewardAmountInWei != 0 && _rewardAmountInWei != rewardAmountInWei,"Invalid Reward Amount");
        require(maxParticipants > participantCount, "Invalid Request: All Rewards claimed");
        if (rewardAmountInWei < _rewardAmountInWei) {
            // Reward Value increased. Transfer token into the contract.
            uint256 transferAmount = (_rewardAmountInWei - rewardAmountInWei) * (maxParticipants - participantCount);
            IERC20(rewardToken).safeTransferFrom(msg.sender,address(this), transferAmount);
        } else {
            // Reward Value decreased. Transfer token from the contract.
            uint256 transferAmount = (rewardAmountInWei - _rewardAmountInWei) * (maxParticipants - participantCount);
            IERC20(rewardToken).safeTransfer(msg.sender, transferAmount);
        }
        rewardAmountInWei = _rewardAmountInWei;
    }

    function updateTotalParticipants(
        uint256 _maxParticipants
    ) external nonReentrant onlyOwner {
        require(_maxParticipants != 0 && _maxParticipants != maxParticipants, "Invalid Participant Count");
        if (maxParticipants < _maxParticipants) {
            // Max Participants Increased. Transfer token into the contract.
            uint256 transferAmount = (rewardAmountInWei * (_maxParticipants - maxParticipants));
            IERC20(rewardToken).safeTransferFrom(msg.sender,address(this), transferAmount);
        } else {
            // Reward Value decreased. Transfer token from the contract.
            uint256 transferAmount = (rewardAmountInWei * (maxParticipants - _maxParticipants));
            IERC20(rewardToken).safeTransfer(msg.sender, transferAmount);
        }
        maxParticipants = _maxParticipants;
    }

    function extendQuest(
        uint256 _endTime
    ) external nonReentrant onlyOwner {
        endTime = _endTime;
    }
}