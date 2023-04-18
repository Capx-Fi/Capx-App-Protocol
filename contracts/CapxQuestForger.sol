//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICapxQuestForger} from "./interfaces/ICapxQuestForger.sol";
import {CapxQuest as CapxQuestContract} from "./CapxQuest.sol";
import {CapxIOUQuest} from "./CapxIOUQuest.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

interface ICapxIOUQuest {
     function claim(
        bytes32 _messageHash,
        bytes memory _signature,
        address _sender
    ) external;
}

contract CapxQuestForger is Initializable, UUPSUpgradeable, OwnableUpgradeable, ICapxQuestForger {
    using SafeERC20 for IERC20;
    bytes32 public constant IOU = keccak256(abi.encodePacked("iou"));

    struct CapxQuest {
        address questAddress;
        uint maxParticipants;
        uint participantCount;
    }

    address public claimSignerAddress;
    address public feeReceiver;
    address public capxIOUQuestAddress;

    mapping(address => bool) public isCapxQuest;

    mapping(string => CapxQuest) public capxQuests;
    mapping(string => address) public capxQuestsAddress;

    uint16 public questFee;

    constructor() initializer {}

    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    function initialize(
        address _claimSignerAddress,
        address _feeReceiver,
        address _capxIOUQuestAddress,
        address _owner
    ) external initializer {
        if (_claimSignerAddress == address(0)) revert ZeroAddressNotAllowed();
        if (_feeReceiver == address(0)) revert ZeroAddressNotAllowed();
        if (_capxIOUQuestAddress == address(0)) revert ZeroAddressNotAllowed();
        if (_owner == address(0)) revert ZeroAddressNotAllowed();

        __Ownable_init();
        _transferOwnership(_owner);

        claimSignerAddress = _claimSignerAddress;
        feeReceiver = _feeReceiver;
        questFee = 200;
        capxIOUQuestAddress = _capxIOUQuestAddress;
    }

    function createQuest(
        address _rewardToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxParticipants,
        uint256 _rewardAmountInWei,
        string memory _questRewardType,
        string memory _questId
    ) external onlyOwner returns (address) {
        if (_rewardToken == address(0)) revert ZeroAddressNotAllowed();

        CapxQuest storage currCapxQuest = capxQuests[_questId];

        if(currCapxQuest.questAddress != address(0)) revert QuestIdUsed();
        if (keccak256(abi.encodePacked(_questRewardType)) == IOU) {
            // Reward Type IOU.
            // TODO: Check for Reward Token in Whitelist.
            address newCapxQuest = Clones.clone(capxIOUQuestAddress);
            isCapxQuest[newCapxQuest] = true;
            capxQuestsAddress[_questId] = newCapxQuest;

            // Transfer the tokens.
            uint256 requiredTokens = ((10_000 + questFee) * (_maxParticipants * _rewardAmountInWei)) / 10_000;
            IERC20(_rewardToken).safeTransferFrom(msg.sender, newCapxQuest, requiredTokens);

            emit CapxQuestCreated(
                msg.sender,
                address(newCapxQuest),
                _questId,
                _questRewardType,
                _rewardToken,
                _startTime,
                _endTime,
                _maxParticipants,
                _rewardAmountInWei
            );

            currCapxQuest.questAddress = address(newCapxQuest);
            currCapxQuest.maxParticipants = _maxParticipants;

            CapxIOUQuest(newCapxQuest).initialize(
                _rewardToken,
                _startTime,
                _endTime,
                _maxParticipants,
                _rewardAmountInWei,
                _questId,
                questFee,
                feeReceiver
            );

            CapxIOUQuest(newCapxQuest).transferOwnership(msg.sender);
            return newCapxQuest;
        } else {
            revert QuestRewardTypeInvalid();
        }
    }

    function setCapxIOUQuestAddress(address _capxIOUQuestAddress) public onlyOwner {
        if (_capxIOUQuestAddress == address(0)) revert ZeroAddressNotAllowed();
        capxIOUQuestAddress = _capxIOUQuestAddress;
    }

    function setClaimSignerAddress(address _claimSignerAddress) public onlyOwner {
        if (_claimSignerAddress == address(0)) revert ZeroAddressNotAllowed();
        claimSignerAddress = _claimSignerAddress;
    }

    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        if (_feeReceiver == address(0)) revert ZeroAddressNotAllowed();
        feeReceiver = _feeReceiver;
    }

    function setQuestFee(uint16 _questFee) public onlyOwner {
        questFee = _questFee;
    }

    function getClaimedNumber(string memory _questId) external view returns(uint) {
        return capxQuests[_questId].participantCount;
    }

    function claim(
        bytes32 _messageHash,
        bytes memory _signature,
        string memory _questId
    ) external {
        address capxQuest = capxQuestsAddress[_questId];
        require(address(capxQuest) != address(0) && isCapxQuest[capxQuest], "Invalid Capx Quest ID");
        ICapxIOUQuest(capxQuest).claim(
            _messageHash,
            _signature,
            msg.sender
        );
    }

    function emitClaim(
        address _questAddress,
        string memory _questId,
        address _claimer,
        address _rewardToken,
        uint256 _rewardAmount
    ) external {
        require(msg.sender == _questAddress, "NOT Authorized");
        require(isCapxQuest[msg.sender], "NOT Capx Quest");

        CapxQuest storage currCapxQuest = capxQuests[_questId];
        ++currCapxQuest.participantCount;

        emit CapxQuestRewardClaimed(
            msg.sender,
            _questId,
            _claimer,
            _rewardToken,
            _rewardAmount
        );
    }

    function questInfo(string memory questId_) external view returns (address, uint, uint) {
        CapxQuest storage currCapxQuest = capxQuests[questId_];
        return (currCapxQuest.questAddress, currCapxQuest.maxParticipants, currCapxQuest.participantCount);
    }
}
