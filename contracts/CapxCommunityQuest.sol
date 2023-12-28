//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18 .0;
pragma abicoder v2;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ICapxCommunityQuest} from "./interfaces/ICapxCommunityQuest.sol";
import {ICapxCommunityQuestForger} from "./interfaces/ICapxCommunityQuestForger.sol";
import {ITokenPoweredByCapx} from "./interfaces/ITokenPoweredByCapx.sol";
import {StringHelper} from "./library/StringHelper.sol";

contract CapxCommunityQuest is
    ReentrancyGuard,
    PausableUpgradeable,
    OwnableUpgradeable,
    ICapxCommunityQuest
{
    using StringHelper for bytes;
    using StringHelper for uint256;
    using SafeERC20 for IERC20;

    string public communityId;
    uint256 public communityQuestCount;
    bool public isCommunityActive;

    struct CapxQuestDetails {
        address rewardToken;
        uint256 totalRewardAmountInWei;
        uint256 maxRewardAmountInWei;
        uint256 claimedRewards;
        uint256 claimedParticipants;
    }

    ICapxCommunityQuestForger public capxCommunityQuestForger;

    mapping(string => uint256) private communityQuestToId;
    mapping(uint256 => bool) public isCommunityQuest;
    mapping(uint256 => CapxQuestDetails) public communityQuestDetails;
    mapping(address => uint256) private lastKnownBalance;
    mapping(uint256 => mapping(address => mapping(uint256 => bool)))
        private claimedUsers;

    modifier onlyForger() {
        if (_msgSender() != address(capxCommunityQuestForger))
            revert NotAuthorized();
        _;
    }

    modifier onlyActiveCommunity() {
        if (isCommunityActive == false) revert CommunityNotActive();
        _;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unPause() external onlyOwner whenPaused {
        _unpause();
    }

    function transferOwnership(
        address newOwner
    ) public virtual override(OwnableUpgradeable) onlyOwner {
        if (newOwner == address(0)) revert ZeroAddressNotAllowed();
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

    function setQuestDetails(
        QuestDTO memory quest
    ) external nonReentrant whenNotPaused onlyForger {
        // Transfer tokens.
        ITokenPoweredByCapx(quest.rewardToken).addToWhitelist(address(this));
        IERC20(quest.rewardToken).safeTransferFrom(
            quest.caller,
            address(this),
            quest.totalRewardAmountInWei
        );
        if (
            IERC20(quest.rewardToken).balanceOf(address(this)) -
                lastKnownBalance[quest.rewardToken] <
            quest.totalRewardAmountInWei
        ) revert TotalRewardsExceedsAvailableBalance();

        CapxQuestDetails memory currCapxQuest = communityQuestDetails[
            quest.questNumber
        ];
        string memory _communityQuestId = string(
            abi.encodePacked(communityId, "_", uintToStr(quest.questNumber))
        );
        if (currCapxQuest.rewardToken != address(0)) revert QuestIdUsed();

        // Fill up the Quest Details.
        currCapxQuest = CapxQuestDetails({
            rewardToken: quest.rewardToken,
            totalRewardAmountInWei: quest.totalRewardAmountInWei,
            maxRewardAmountInWei: quest.maxRewardAmountInWei,
            claimedRewards: 0,
            claimedParticipants: 0
        });

        lastKnownBalance[quest.rewardToken] += quest.totalRewardAmountInWei;
        isCommunityQuest[quest.questNumber] = true;
        communityQuestCount += 1;
        communityQuestToId[_communityQuestId] = quest.questNumber;
    }

    function claim(
        string memory _communityQuestId,
        address _receiver,
        uint256 _timestamp,
        uint256 _rewardAmountInWei
    )
        external
        virtual
        override
        nonReentrant
        whenNotPaused
        onlyForger
        onlyActiveCommunity
        returns (address)
    {
        uint256 _questNumber = communityQuestToId[_communityQuestId];
        if (_timestamp > block.timestamp) revert CannotClaimFutureReward();
        if (_questNumber == 0) revert InvalidQuestId();
        if (isCommunityQuest[_questNumber] == false) revert InvalidQuestId();
        if (isCommunityActive == false) revert CommunityNotActive();
        if (claimedUsers[_questNumber][_receiver][_timestamp] == true)
            revert AlreadyClaimed();

        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questNumber
        ];
        if (
            IERC20(currCapxQuest.rewardToken).balanceOf(address(this)) <
            _rewardAmountInWei
        ) revert NoRewardsToClaim();

        if (currCapxQuest.maxRewardAmountInWei < _rewardAmountInWei)
            revert RewardsExceedAllowedLimit();
        if (
            currCapxQuest.totalRewardAmountInWei <
            currCapxQuest.claimedRewards + _rewardAmountInWei
        ) revert NoRewardsToClaim();

        claimedUsers[_questNumber][_receiver][_timestamp] = true;
        currCapxQuest.claimedParticipants += 1;

        currCapxQuest.claimedRewards += _rewardAmountInWei;
        lastKnownBalance[currCapxQuest.rewardToken] -= _rewardAmountInWei;

        // Transfer Tokens.
        require(
            IERC20(currCapxQuest.rewardToken).approve(
                _receiver,
                _rewardAmountInWei
            ),
            "Failed Approval."
        );
        IERC20(currCapxQuest.rewardToken).safeTransfer(
            _receiver,
            _rewardAmountInWei
        );

        return currCapxQuest.rewardToken;
    }

    function isClaimed(
        uint256 _questId,
        address _addressInScope,
        uint256 _timestamp
    ) external view returns (bool) {
        return claimedUsers[_questId][_addressInScope][_timestamp];
    }

    function getRewardToken(uint256 _questId) external view returns (address) {
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questId
        ];
        return currCapxQuest.rewardToken;
    }

    function disableQuest(
        uint256 _questNumber
    ) external nonReentrant onlyForger {
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questNumber
        ];
        uint256 pendingRewards = currCapxQuest.totalRewardAmountInWei -
            currCapxQuest.claimedRewards;
        if (
            IERC20(currCapxQuest.rewardToken).balanceOf(address(this)) <
            pendingRewards
        ) revert NoRewardsToWithdraw();

        lastKnownBalance[currCapxQuest.rewardToken] -= pendingRewards;

        require(
            IERC20(currCapxQuest.rewardToken).approve(owner(), pendingRewards),
            "Approval failed."
        );
        IERC20(currCapxQuest.rewardToken).safeTransfer(owner(), pendingRewards);
    }

    function enableQuest(
        uint256 _questNumber
    ) external nonReentrant onlyForger {
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questNumber
        ];
        uint256 pendingRewards = currCapxQuest.totalRewardAmountInWei -
            currCapxQuest.claimedRewards;
        IERC20(currCapxQuest.rewardToken).safeTransferFrom(
            owner(),
            address(this),
            pendingRewards
        );

        lastKnownBalance[currCapxQuest.rewardToken] += pendingRewards;
    }

    function updateTotalRewards(
        address _caller,
        uint256 _questNumber,
        uint256 _rewardAmount,
        bool _maxParticipantsIncreased
    ) external nonReentrant onlyForger {
        if (isCommunityQuest[_questNumber] == false) revert InvalidQuestId();
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questNumber
        ];

        if (_maxParticipantsIncreased) {
            // Max Participants Increased. Transfer tokens into the contract.
            IERC20(currCapxQuest.rewardToken).safeTransferFrom(
                _caller,
                address(this),
                _rewardAmount
            );
            lastKnownBalance[currCapxQuest.rewardToken] += _rewardAmount;
            currCapxQuest.totalRewardAmountInWei += _rewardAmount;
        } else {
            // Max Participants Decreased. Transfer tokens from the contract.
            uint256 updatedRewardAmtInWei = currCapxQuest
                .totalRewardAmountInWei - _rewardAmount;
            if (updatedRewardAmtInWei < currCapxQuest.claimedRewards)
                revert ClaimedRewardsExceedTotalRewards();
            currCapxQuest.totalRewardAmountInWei = updatedRewardAmtInWei;
            lastKnownBalance[currCapxQuest.rewardToken] -= _rewardAmount;

            IERC20(currCapxQuest.rewardToken).safeTransfer(
                _caller,
                _rewardAmount
            );
        }
    }

    function withdrawTokens(
        address[] memory tokens
    ) external nonReentrant onlyForger {
        isCommunityActive = false;
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(
                _msgSender(),
                IERC20(tokens[i]).balanceOf(address(this))
            );
        }
    }

    function withdrawETH() public onlyOwner nonReentrant {
        (bool sendSuccess, bytes memory sendResponse) = payable(_msgSender())
            .call{value: address(this).balance}("");
        require(
            sendSuccess,
            string(
                bytes("Native Transfer Failed: ").concat(
                    bytes(sendResponse.getRevertMsg())
                )
            )
        );
    }
}