//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICapxQuestForger} from "./interfaces/ICapxQuestForger.sol";
import {ICapxIOUQuest} from "./interfaces/ICapxIOUQuest.sol";
import {ICapxIOUToken} from "./interfaces/ICapxIOUToken.sol";
import {CapxQuest as CapxQuestContract} from "./CapxQuest.sol";
import {CapxIOUQuest} from "./CapxIOUQuest.sol";
import {ICapxIOUForger} from "./interfaces/ICapxIOUForger.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

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
    address public capxIOUForger;

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
        address _owner,
        address _capxIOUForger
    ) external initializer {
        if (_claimSignerAddress == address(0)) revert ZeroAddressNotAllowed();
        if (_feeReceiver == address(0)) revert ZeroAddressNotAllowed();
        if (_capxIOUQuestAddress == address(0)) revert ZeroAddressNotAllowed();
        if (_capxIOUForger == address(0)) revert ZeroAddressNotAllowed();
        if (_owner == address(0)) revert ZeroAddressNotAllowed();

        __Ownable_init();
        _transferOwnership(_owner);

        claimSignerAddress = _claimSignerAddress;
        feeReceiver = _feeReceiver;
        questFee = 0;
        capxIOUQuestAddress = _capxIOUQuestAddress;
        capxIOUForger = _capxIOUForger;
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
        require(ICapxIOUForger(capxIOUForger).isCapxIOUToken(_rewardToken),"NOT Capx Generated IOU");
        CapxQuest storage currCapxQuest = capxQuests[_questId];

        if(currCapxQuest.questAddress != address(0)) revert QuestIdUsed();
        if (keccak256(abi.encodePacked(_questRewardType)) == IOU) {
            // Reward Type IOU.
            // TODO: Check for Reward Token in Whitelist.
            bytes32 salt = keccak256(abi.encodePacked(_questId));
            address newCapxQuest = Clones.cloneDeterministic(capxIOUQuestAddress,salt);
            isCapxQuest[newCapxQuest] = true;
            capxQuestsAddress[_questId] = newCapxQuest;
            ICapxIOUToken(_rewardToken).addToWhitelist(newCapxQuest);
            
            {
                // Transfer the tokens.
                uint256 requiredTokens = ((10_000 + questFee) * (_maxParticipants * _rewardAmountInWei)) / 10_000;
                IERC20(_rewardToken).safeTransferFrom(msg.sender, newCapxQuest, requiredTokens);
            }

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

    function setCapxIOUForger(address _capxIOUForger) public onlyOwner {
        if (_capxIOUForger == address(0)) revert ZeroAddressNotAllowed();
        capxIOUForger = _capxIOUForger;
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

    function predictQuestAddress(string memory _questId) external view returns(address) {
        bytes32 salt = keccak256(abi.encodePacked(_questId));
        return Clones.predictDeterministicAddress(capxIOUQuestAddress,salt);
    }

    function claim(
        bytes32 _messageHash,
        bytes memory _signature,
        string memory _questId,
        address _receiver
    ) external {
        address capxQuest = capxQuestsAddress[_questId];
        if (_receiver == address(0)) revert ZeroAddressNotAllowed();
        require(address(capxQuest) != address(0) && isCapxQuest[capxQuest], "Invalid Capx Quest ID");
        ICapxIOUQuest(capxQuest).claim(
            _messageHash,
            _signature,
            msg.sender,
            _receiver
        );
    }

    function emitClaim(
        address _questAddress,
        string memory _questId,
        address _claimer,
        address _claimReceiver,
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
            _claimReceiver,
            _rewardToken,
            _rewardAmount
        );
    }

    function questInfo(string memory questId_) external view returns (address, uint, uint) {
        CapxQuest storage currCapxQuest = capxQuests[questId_];
        return (currCapxQuest.questAddress, currCapxQuest.maxParticipants, currCapxQuest.participantCount);
    }
}
