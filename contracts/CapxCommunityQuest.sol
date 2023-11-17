//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
pragma abicoder v2;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {ICapxCommunityQuest} from "./interfaces/ICapxCommunityQuest.sol";
import {ICapxCommunityQuestForger} from "./interfaces/ICapxCommunityQuestForger.sol";
import {StringHelper} from "./library/StringHelper.sol";

contract CapxCommunityQuest is ReentrancyGuard, PausableUpgradeable, OwnableUpgradeable, ICapxCommunityQuest {
    using StringHelper for bytes;
    using StringHelper for uint256;
    using SafeERC20 for IERC20;

    string public communityId;
    uint256 public communityQuestCount;
    bool public isCommunityActive;

    ICapxCommunityQuestForger public capxCommunityQuestForger;

    mapping(string => uint256) private communityQuestToId;
    mapping(uint256 => bool) public isCommunityQuest;
    mapping(uint256 => CapxQuestDetails) public communityQuestDetails;
    mapping(address => uint256) private lastKnownBalance;
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) private claimedUsers;

    struct CapxQuestDetails {
        uint256 startTime;
        uint256 endTime;
        address rewardToken;
        uint256 totalRewardAmountInWei;
        uint256 maxRewardAmountInWei;
        uint256 maxParticipants;
        uint256 claimedRewards;
        uint256 claimedParticipants;
        bool active;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unPause() external onlyOwner whenPaused {
        _unpause();
    }

    function transferOwnership(address newOwner) public virtual override(OwnableUpgradeable) onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        capxCommunityQuestForger.updateCommunityOwner(owner(), newOwner);
        _transferOwnership(newOwner);
    }

    function uintToStr(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function recoverSigner(bytes32 messagehash, bytes memory signature) public pure returns (address) {
        bytes32 messageDigest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messagehash));
        return ECDSAUpgradeable.recover(messageDigest, signature);
    }

    function initialize(
        address _owner,
        string memory _communityId
    ) public initializer {
        communityId = _communityId;
        capxCommunityQuestForger = ICapxCommunityQuestForger(_msgSender());
        isCommunityActive = true;

        __Ownable_init();
        __Pausable_init();
        _transferOwnership(_owner);
    }

    function createQuest(
        uint256 _startTime,
        uint256 _endTime,
        address _rewardToken,
        uint256 _questId,
        uint256 _maxParticipants,
        uint256 _totalRewardAmountInWei,
        uint256 _maxRewardAmountInWei
    ) external virtual nonReentrant whenNotPaused {
        require(_msgSender() == address(capxCommunityQuestForger),"NOT Authorized to call.");
        if (_startTime <= block.timestamp) revert InvalidStartTime();
        if (_endTime <= block.timestamp || _endTime <= _startTime) revert InvalidEndTime();
        if(IERC20(_rewardToken).balanceOf(address(this)) - lastKnownBalance[_rewardToken] < _totalRewardAmountInWei) revert TotalRewardsExceedsAvailableBalance();
        
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[_questId];
        string memory _communityQuestId = string(abi.encodePacked(communityId,"_",uintToStr(_questId)));
        if(currCapxQuest.rewardToken != address(0)) revert QuestIdUsed();
        
        // Fill up the Quest Details.
        currCapxQuest.active = true;
        currCapxQuest.startTime = _startTime;
        currCapxQuest.endTime = _endTime;
        currCapxQuest.maxParticipants = _maxParticipants;
        currCapxQuest.maxRewardAmountInWei = _maxRewardAmountInWei;
        currCapxQuest.totalRewardAmountInWei = _totalRewardAmountInWei;
        currCapxQuest.rewardToken = _rewardToken;

        lastKnownBalance[_rewardToken] += _totalRewardAmountInWei;
        isCommunityQuest[_questId] = true;
        communityQuestCount += 1;
        communityQuestToId[_communityQuestId] = _questId;
    }

    function claim(
        bytes32 _messageHash,
        bytes memory _signature,
        string memory _communityQuestId,
        address _receiver,
        uint256 _timestamp,
        uint256 _rewardAmountInWei
    ) external virtual override nonReentrant whenNotPaused {
        uint256 _questId = communityQuestToId[_communityQuestId];
        require(_msgSender() == address(capxCommunityQuestForger),"NOT Authorized to call.");
        require(_timestamp < block.timestamp, "Cannot Claim Future Rewards");
        require(_questId != 0, "Invalid Community QuestId");
        if(isCommunityQuest[_questId] == false) revert InvalidQuestId();
        if(isCommunityActive == false) revert CommunityNotActive();
        if(claimedUsers[_questId][_receiver][_timestamp] == true) revert AlreadyClaimed();
        if(keccak256(abi.encodePacked(_receiver,_communityQuestId,_timestamp,_rewardAmountInWei)) != _messageHash) revert InvalidMessageHash();
        if (recoverSigner(_messageHash, _signature) != capxCommunityQuestForger.claimSignerAddress()) revert InvalidSigner();

        CapxQuestDetails storage currCapxQuest = communityQuestDetails[_questId];
        if(currCapxQuest.active == false) revert QuestNotActive();
        if(IERC20(currCapxQuest.rewardToken).balanceOf(address(this)) < _rewardAmountInWei) revert NoRewardsToClaim();
        if (block.timestamp < currCapxQuest.startTime) revert QuestNotStarted();
        if (_timestamp > currCapxQuest.endTime) revert QuestEnded();
        if(currCapxQuest.maxRewardAmountInWei < _rewardAmountInWei) revert RewardsExceedAllowedLimit();
        if(currCapxQuest.totalRewardAmountInWei < currCapxQuest.claimedRewards + _rewardAmountInWei) revert NoRewardsToClaim();
        if(currCapxQuest.maxParticipants < currCapxQuest.claimedParticipants + 1) revert OverMaxParticipants();

        claimedUsers[_questId][_receiver][_timestamp] = true;
        currCapxQuest.claimedParticipants+=1;
        currCapxQuest.claimedRewards+=_rewardAmountInWei;
        lastKnownBalance[currCapxQuest.rewardToken]-=_rewardAmountInWei;

        // Transfer Tokens.
        require(IERC20(currCapxQuest.rewardToken).approve(_receiver,_rewardAmountInWei));
        IERC20(currCapxQuest.rewardToken).safeTransfer(_receiver,_rewardAmountInWei);

        // Emit Event.
        capxCommunityQuestForger.emitClaim(
            address(this), 
            _communityQuestId, 
            _receiver, 
            _timestamp, 
            currCapxQuest.rewardToken, 
            _rewardAmountInWei
        );
    }

    function isClaimed(uint256 _questId, address _addressInScope, uint256 _timestamp) external view returns (bool) {
        return claimedUsers[_questId][_addressInScope][_timestamp];
    }

    function getRewardToken(uint256 _questId) external view returns (address) {
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[_questId];
        return currCapxQuest.rewardToken;
    }

    function disableQuest(uint256 _questId) external nonReentrant onlyOwner {
        if(isCommunityQuest[_questId] == false) revert InvalidQuestId();
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[_questId];
        uint256 pendingRewards = currCapxQuest.totalRewardAmountInWei - currCapxQuest.claimedRewards;
        require(IERC20(currCapxQuest.rewardToken).balanceOf(address(this)) >= pendingRewards, "No Rewards to withdraw");

        currCapxQuest.active = false;
        lastKnownBalance[currCapxQuest.rewardToken]-=pendingRewards;

        require(IERC20(currCapxQuest.rewardToken).approve(_msgSender(),pendingRewards));
        IERC20(currCapxQuest.rewardToken).safeTransfer(_msgSender(),pendingRewards);
    }

    function enableQuest(uint256 _questId) external nonReentrant onlyOwner {
        if(isCommunityQuest[_questId] == false) revert InvalidQuestId();
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[_questId];
        uint256 pendingRewards = currCapxQuest.totalRewardAmountInWei - currCapxQuest.claimedRewards;
        IERC20(currCapxQuest.rewardToken).safeTransferFrom(_msgSender(),address(this),pendingRewards);

        currCapxQuest.active = true;
        lastKnownBalance[currCapxQuest.rewardToken]+=pendingRewards;
    }

    function updateTotalRewards(uint256 _questId, uint256 _rewardAmount, uint256 _maxParticipants) external nonReentrant onlyOwner {
        if(isCommunityQuest[_questId] == false) revert InvalidQuestId();
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[_questId];
        if(currCapxQuest.active == false) revert QuestNotActive();

        if (currCapxQuest.maxParticipants < _maxParticipants) {
            // Max Participants Increased. Transfer tokens into the contract.
            IERC20(currCapxQuest.rewardToken).safeTransferFrom(_msgSender(),address(this),_rewardAmount);
            lastKnownBalance[currCapxQuest.rewardToken] += _rewardAmount;
            currCapxQuest.totalRewardAmountInWei += _rewardAmount;
            
        } else {
            // Max Participants Decreased. Transfer tokens from the contract.
            uint256 updatedRewardAmtInWei = currCapxQuest.totalRewardAmountInWei - _rewardAmount;
            if (updatedRewardAmtInWei < currCapxQuest.claimedRewards) revert ClaimedRewardsExceedTotalRewards();
            currCapxQuest.totalRewardAmountInWei = updatedRewardAmtInWei;
            lastKnownBalance[currCapxQuest.rewardToken] -= _rewardAmount;

            IERC20(currCapxQuest.rewardToken).safeTransfer(_msgSender(),_rewardAmount);
        }
        currCapxQuest.maxParticipants = _maxParticipants;
    }

    function extendQuest(
        uint256 _questId,
        uint256 _endTime
    ) external nonReentrant onlyOwner {
        if (_endTime <= block.timestamp) revert InvalidEndTime();
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[_questId];
        currCapxQuest.endTime = _endTime;
    }

    function withdrawTokens(address[] memory tokens) external nonReentrant onlyOwner {
        isCommunityActive = false;
        for(uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(_msgSender(),IERC20(tokens[i]).balanceOf(address(this)));
        }
    }

    function toggleCommunity() external onlyOwner {
        isCommunityActive = !isCommunityActive;
    }

    function withdrawETH() public onlyOwner {
        (bool sendSuccess, bytes memory sendResponse) = payable(_msgSender()).call{value: address(this).balance}("");
        require(sendSuccess,string(bytes("Native Transfer Failed: ").concat(bytes(sendResponse.getRevertMsg()))));
    }
}