//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
pragma abicoder v2;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CapxCommunityQuest} from "./CapxCommunityQuest.sol";
import {ICapxCommunityQuest} from "./interfaces/ICapxCommunityQuest.sol";
import {ICapxCommunityQuestForger} from "./interfaces/ICapxCommunityQuestForger.sol";
import {ITokenPoweredByCapx} from "./interfaces/ITokenPoweredByCapx.sol";
import {ICapxTokenForger} from "./interfaces/ICapxTokenForger.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {ICapxReputationScore} from "./interfaces/ICapxReputationScore.sol";

contract CapxCommunityQuestForger is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard,
    ICapxCommunityQuestForger
{
    using SafeERC20 for IERC20;

    address public claimSignerAddress;
    address public capxCommunityQuest;

    string public capxCommunityId;
    uint256 public taskCount;

    ICapxTokenForger public capxTokenForger;
    ICapxReputationScore public capxReputationScore;

    mapping(string => address) public isCapxCommunityQuest;
    mapping(string => bool) public isCapxTask;
    mapping(address => bool) public isCapxCommunity;
    mapping(string => address) public community;
    mapping(address => address) private communityOwners;
    mapping(string => address) public communityOwner;
    mapping(address => string) private communityAddresstoId;
    mapping(string => uint256) public communityQuestCount;
    mapping(string => CapxQuestDetails) public communityQuestDetails; // questId -> CapxQuestDetails
    mapping(string => CapxTaskDetails) public taskDetails; // taskId -> CapxQuestDetails

    mapping(string => mapping(address => bool)) private communityAuthorized;

    constructor() initializer {}

    modifier onlyCommunityOwners(string calldata _communityId) {
        if (communityOwners[_msgSender()] == address(0)) revert NotAuthorized();
        if (communityOwners[_msgSender()] != community[_communityId])
            revert NotAuthorized();
        _;
    }

    modifier onlyCommunityAuthorized(string calldata communityId) {
        if (!communityAuthorized[communityId][_msgSender()])
            revert NotAuthorized();
        _;
    }

    modifier onlyCapxCommunityAuthorized() {
        if (community[capxCommunityId] == address(0))
            revert CapxCommunityIdNotSet();
        if (communityAuthorized[capxCommunityId][_msgSender()])
            revert NotAuthorized();
        _;
    }

    function _authorizeUpgrade(
        address _newImplementation
    ) internal override onlyOwner {}

    function initialize(
        address _claimSignerAddress,
        address _capxCommunityQuest,
        address _capxReputationScore,
        address _owner,
        address _capxTokenForger
    ) external initializer {
        if (_claimSignerAddress == address(0)) revert ZeroAddressNotAllowed();
        if (_capxTokenForger == address(0)) revert ZeroAddressNotAllowed();
        if (_owner == address(0)) revert ZeroAddressNotAllowed();
        if (_capxCommunityQuest == address(0)) revert ZeroAddressNotAllowed();
        if (_capxReputationScore == address(0)) revert ZeroAddressNotAllowed();

        __Ownable_init();
        __Pausable_init();
        _transferOwnership(_owner);

        claimSignerAddress = _claimSignerAddress;
        capxTokenForger = ICapxTokenForger(_capxTokenForger);
        capxReputationScore = ICapxReputationScore(_capxReputationScore);
        capxCommunityQuest = _capxCommunityQuest;
    }

    /// @notice function to Pause smart contract.
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @notice function to UnPause smart contract
    function unPause() public onlyOwner whenPaused {
        _unpause();
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

    function createCommunity(
        address _owner,
        string memory _communityId
    ) external onlyOwner whenNotPaused {
        if (_owner == address(0)) revert ZeroAddressNotAllowed();
        if (communityOwners[_owner] != address(0)) revert OwnerOwnsACommunity();
        if (community[_communityId] != address(0))
            revert CommunityAlreadyExists();

        bytes32 salt = keccak256(abi.encodePacked(_communityId));
        address communityAddress = Clones.cloneDeterministic(
            capxCommunityQuest,
            salt
        );
        community[_communityId] = communityAddress;
        communityOwner[_communityId] = _owner;
        communityOwners[_owner] = communityAddress;
        communityAuthorized[_communityId][_owner] = true;
        isCapxCommunity[communityAddress] = true;
        communityAddresstoId[communityAddress] = _communityId;
        CapxCommunityQuest(communityAddress).initialize(_owner, _communityId);
    }

    function createQuest(
        CreateQuest calldata quest
    )
        external
        nonReentrant
        onlyCommunityOwners(quest.communityId)
        whenNotPaused
    {
        if (quest.startTime <= block.timestamp) revert InvalidStartTime();
        if (
            quest.endTime <= block.timestamp || quest.endTime <= quest.startTime
        ) revert InvalidEndTime();

        if (quest.rewardType != 2 && quest.rewardToken == address(0))
            revert ZeroAddressNotAllowed();
        if (
            quest.rewardType != 2 &&
            !capxTokenForger.isTokenPoweredByCapx(quest.rewardToken)
        ) revert NotCapxGeneratedToken();

        address communityAddress = community[quest.communityId];
        if (community[quest.communityId] == address(0))
            revert InvalidCommunityId();

        string memory _questId = string(
            abi.encodePacked(
                quest.communityId,
                "_",
                uintToStr(quest.questNumber)
            )
        );

        if (isCapxCommunityQuest[_questId] != address(0)) revert QuestIdUsed();
        if (quest.rewardType < 1 || quest.rewardType > 3)
            revert InvalidRewardType();

        communityQuestDetails[_questId] = CapxQuestDetails({
            communityId: quest.communityId,
            startTime: quest.startTime,
            endTime: quest.endTime,
            maxParticipants: quest.maxParticipants,
            rewardType: quest.rewardType,
            claimedParticipants: 0,
            questNumber: quest.questNumber,
            active: true
        });

        // Create Quest.
        if (quest.rewardType == 1) {
            ITokenPoweredByCapx(quest.rewardToken).addToWhitelist(
                communityAddress
            );
            ICapxCommunityQuest(communityAddress).setQuestDetails(
                ICapxCommunityQuest.QuestDTO({
                    rewardToken: quest.rewardToken,
                    questNumber: quest.questNumber,
                    totalRewardAmountInWei: quest.totalRewardAmountInWei,
                    maxRewardAmountInWei: quest.maxRewardAmountInWei,
                    caller: _msgSender()
                })
            );
        } else if (quest.rewardType == 2) {
            capxReputationScore.setQuestDetails(
                ICapxReputationScore.QuestDTO({
                    communityQuestId: _questId,
                    reputationType: quest.reputationType,
                    maxReputationScore: quest.maxReputationScore
                })
            );
        } else if (quest.rewardType == 3) {
            ITokenPoweredByCapx(quest.rewardToken).addToWhitelist(
                communityAddress
            );
            ICapxCommunityQuest(communityAddress).setQuestDetails(
                ICapxCommunityQuest.QuestDTO({
                    rewardToken: quest.rewardToken,
                    questNumber: quest.questNumber,
                    totalRewardAmountInWei: quest.totalRewardAmountInWei,
                    maxRewardAmountInWei: quest.maxRewardAmountInWei,
                    caller: _msgSender()
                })
            );
            capxReputationScore.setQuestDetails(
                ICapxReputationScore.QuestDTO({
                    communityQuestId: _questId,
                    reputationType: quest.reputationType,
                    maxReputationScore: quest.maxReputationScore
                })
            );
        }
        isCapxCommunityQuest[_questId] = communityAddress;
        communityQuestCount[quest.communityId] += 1;
    }

    function createTask(
        CreateTask calldata task
    ) external nonReentrant onlyCapxCommunityAuthorized whenNotPaused {
        string memory _taskId = string(
            abi.encodePacked(capxCommunityId, ":", uintToStr(task.taskNumber))
        );
        if (isCapxTask[_taskId] == true) revert TaskNumberUsed();

        taskDetails[_taskId] = CapxTaskDetails({
            taskNumber: task.taskNumber,
            claimedParticipants: 0,
            active: true
        });

        capxReputationScore.setQuestDetails(
            ICapxReputationScore.QuestDTO({
                communityQuestId: _taskId,
                reputationType: task.reputationType,
                maxReputationScore: task.maxReputationScore
            })
        );
        isCapxTask[_taskId] = true;
        taskCount += 1;
    }

    function claim(
        bytes32 _messageHash,
        bytes calldata _signature,
        bytes calldata _claimData
    ) external whenNotPaused nonReentrant {
        if (
            keccak256(abi.encodePacked(_msgSender(), _claimData)) !=
            _messageHash
        ) revert InvalidMessageHash();

        if (recoverSigner(_messageHash, _signature) != claimSignerAddress)
            revert InvalidSigner();

        (
            string memory _questId,
            uint256 _timestamp,
            uint256 _rewardAmountInWei,
            uint256 _rewardType,
            uint256 _repType,
            uint256 _repScore
        ) = abi.decode(
                _claimData,
                (string, uint256, uint256, uint256, uint256, uint256)
            );

        address capxQuest = isCapxCommunityQuest[_questId];
        if (capxQuest == address(0)) revert InvalidCommunityAddress();

        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questId
        ];

        if (block.timestamp < currCapxQuest.startTime) revert QuestNotStarted();
        if (_timestamp > currCapxQuest.endTime) revert QuestEnded();
        if (currCapxQuest.active == false) revert QuestNotActive();
        if (
            currCapxQuest.maxParticipants <
            currCapxQuest.claimedParticipants + 1
        ) revert OverMaxParticipants();
        if (currCapxQuest.rewardType != _rewardType)
            revert RewardTypeMismatch();

        currCapxQuest.claimedParticipants += 1;

        if (_rewardType == 1) {
            address rewardToken = ICapxCommunityQuest(capxQuest).claim(
                _questId,
                _msgSender(),
                _timestamp,
                _rewardAmountInWei
            );
            emit CapxCommunityQuestRewardClaimed(
                capxQuest,
                _questId,
                _msgSender(),
                _timestamp,
                rewardToken,
                _rewardAmountInWei
            );
        } else if (_rewardType == 2) {
            capxReputationScore.claim(
                _questId,
                _timestamp,
                _repType,
                _repScore,
                _msgSender()
            );
            emit CapxReputationScoreClaimed(
                capxQuest,
                _questId,
                _msgSender(),
                _timestamp,
                _repType,
                _repScore
            );
        } else if (_rewardType == 3) {
            address rewardToken = ICapxCommunityQuest(capxQuest).claim(
                _questId,
                _msgSender(),
                _timestamp,
                _rewardAmountInWei
            );
            capxReputationScore.claim(
                _questId,
                _timestamp,
                _repType,
                _repScore,
                _msgSender()
            );
            emit CapxCommunityQuestRewardClaimed(
                capxQuest,
                _questId,
                _msgSender(),
                _timestamp,
                rewardToken,
                _rewardAmountInWei
            );
            emit CapxReputationScoreClaimed(
                capxQuest,
                _questId,
                _msgSender(),
                _timestamp,
                _repType,
                _repScore
            );
        } else {
            revert InvalidRewardType();
        }
    }

    function claimTask(
        bytes32 _messageHash,
        bytes calldata _signature,
        bytes calldata _claimData
    ) external whenNotPaused nonReentrant {
        if (community[capxCommunityId] == address(0))
            revert CapxCommunityIdNotSet();

        if (
            keccak256(abi.encodePacked(_msgSender(), _claimData)) !=
            _messageHash
        ) revert InvalidMessageHash();

        if (recoverSigner(_messageHash, _signature) != claimSignerAddress)
            revert InvalidSigner();

        (
            string memory _taskId,
            uint256 _timestamp,
            uint256 _repType,
            uint256 _repScore
        ) = abi.decode(_claimData, (string, uint256, uint256, uint256));

        if (isCapxTask[_taskId] == false) revert InvalidTaskId();

        CapxTaskDetails storage currCapxTask = taskDetails[_taskId];

        if (currCapxTask.active == false) revert TaskNotActive();

        currCapxTask.claimedParticipants += 1;

        capxReputationScore.claim(
            _taskId,
            _timestamp,
            _repType,
            _repScore,
            _msgSender()
        );

        emit CapxTaskClaimed(
            _taskId,
            _msgSender(),
            _timestamp,
            _repType,
            _repScore
        );
    }

    function updateTaskReward(
        uint256 _taskNumber,
        uint256 _reputationType,
        uint256 _maxReputationScore
    ) external onlyCapxCommunityAuthorized {
        string memory _taskId = string(
            abi.encodePacked(capxCommunityId, ":", uintToStr(_taskNumber))
        );

        if (isCapxTask[_taskId] == false) revert TaskIdDoesNotExist();

        CapxTaskDetails storage currentDetails = taskDetails[_taskId];

        if (currentDetails.active == true) revert QuestMustBeDisabled();

        if (address(capxReputationScore) == address(0))
            revert CapxReputationContractNotInitialised();

        capxReputationScore.setQuestDetails(
            ICapxReputationScore.QuestDTO({
                communityQuestId: _taskId,
                reputationType: _reputationType,
                maxReputationScore: _maxReputationScore
            })
        );
    }

    function setCapxCommunityId(
        string memory _capxCommunityId
    ) external onlyOwner {
        if (community[_capxCommunityId] == address(0))
            revert InvalidCommunityId();
        capxCommunityId = _capxCommunityId;
    }

    function updateIOURewards(
        string calldata _communityId,
        uint256 _questNumber,
        uint256 _newTotalRewardAmountInWei,
        uint256 _newMaxRewardAmountInWei,
        uint256 _newMaxParticipants
    ) external onlyCommunityAuthorized(_communityId) nonReentrant {
        if (_newTotalRewardAmountInWei <= 0 || _newMaxParticipants <= 0)
            revert InvalidIOURewards();
        string memory _questId = getQuestId(_communityId, _questNumber);

        if (isCapxCommunityQuest[_questId] == address(0))
            revert QuestIdDoesNotExist();

        address communityAddress = isCapxCommunityQuest[_questId];

        CapxQuestDetails storage currentDetails = communityQuestDetails[
            _questId
        ];

        if (currentDetails.active == true) revert QuestMustBeDisabled();

        if (currentDetails.rewardType != 1 && currentDetails.rewardType != 3)
            revert InvalidRewardType();

        ICapxCommunityQuest(communityAddress).updateRewards(
            _msgSender(),
            _questNumber,
            _newTotalRewardAmountInWei,
            _newMaxRewardAmountInWei
        );
        currentDetails.maxParticipants = _newMaxParticipants;
    }

    function updateClaimSignerAddress(
        address _claimSignerAddress
    ) external onlyOwner {
        if (_claimSignerAddress == address(0)) revert ZeroAddressNotAllowed();
        claimSignerAddress = _claimSignerAddress;
    }

    function updateReputationRewards(
        string calldata _communityId,
        uint256 _questNumber,
        uint256 _newReputationType,
        uint256 _newMaxReputationScore
    ) external nonReentrant onlyCommunityAuthorized(_communityId) {
        string memory _questId = getQuestId(_communityId, _questNumber);

        if (isCapxCommunityQuest[_questId] == address(0))
            revert QuestIdDoesNotExist();

        CapxQuestDetails storage currentDetails = communityQuestDetails[
            _questId
        ];

        if (currentDetails.active == true) revert QuestMustBeDisabled();
        if (currentDetails.rewardType != 2 && currentDetails.rewardType != 3)
            revert InvalidRewardType();

        if (address(capxReputationScore) == address(0))
            revert CapxReputationContractNotInitialised();

        capxReputationScore.setQuestDetails(
            ICapxReputationScore.QuestDTO({
                communityQuestId: _questId,
                reputationType: _newReputationType,
                maxReputationScore: _newMaxReputationScore
            })
        );
    }

    function updateRewardType(
        RewardTypeDTO calldata _rewardUpdateData
    )
        external
        nonReentrant
        onlyCommunityAuthorized(_rewardUpdateData.communityId)
    {
        string memory _questId = getQuestId(
            _rewardUpdateData.communityId,
            _rewardUpdateData.questNumber
        );

        if (isCapxCommunityQuest[_questId] == address(0))
            revert QuestIdDoesNotExist();

        CapxQuestDetails storage currentDetails = communityQuestDetails[
            _questId
        ];

        if (currentDetails.active == true) revert QuestMustBeDisabled();

        if (currentDetails.rewardType == _rewardUpdateData.rewardType)
            revert UseRewardTypeSpecificFunctions();

        address communityAddress = community[_rewardUpdateData.communityId];

        handleIOURewards(communityAddress, _rewardUpdateData, currentDetails);

        handleReputationRewards(
            _questId,
            _rewardUpdateData.rewardType,
            _rewardUpdateData
        );
        currentDetails.maxParticipants = _rewardUpdateData.maxParticipants;
        currentDetails.rewardType = _rewardUpdateData.rewardType;
    }

    function handleIOURewards(
        address communityAddress,
        RewardTypeDTO calldata _rewardUpdateData,
        CapxQuestDetails storage currentDetails
    ) internal {
        // Adding IOU Rewards (Switching to Reward Type 1 or 3 from 2)
        if (
            (currentDetails.rewardType == 2) &&
            (_rewardUpdateData.rewardType == 1 ||
                _rewardUpdateData.rewardType == 3)
        ) {
            ITokenPoweredByCapx(_rewardUpdateData.rewardToken).addToWhitelist(
                communityAddress
            );
            // Logic to transfer ERC20 tokens from the owner to the community contract
            ICapxCommunityQuest(communityAddress).setQuestDetails(
                ICapxCommunityQuest.QuestDTO({
                    rewardToken: _rewardUpdateData.rewardToken,
                    questNumber: _rewardUpdateData.questNumber,
                    totalRewardAmountInWei: _rewardUpdateData
                        .totalRewardAmountInWei,
                    maxRewardAmountInWei: _rewardUpdateData
                        .maxRewardAmountInWei,
                    caller: _msgSender()
                })
            );
        }

        // Removing IOU Rewards (Switching from Reward Type 1 or 3 to 2)
        if (
            (currentDetails.rewardType == 1 ||
                currentDetails.rewardType == 3) &&
            _rewardUpdateData.rewardType == 2
        ) {
            // Logic to transfer ERC20 tokens from the community contract back to the owner
            ICapxCommunityQuest(communityAddress).updateRewards(
                _msgSender(),
                currentDetails.questNumber,
                0,
                0
            );
        }

        // Switching from 1 to 3 or 3 to 1
        if (
            (currentDetails.rewardType == 1 ||
                currentDetails.rewardType == 3) &&
            (_rewardUpdateData.rewardType == 3 ||
                _rewardUpdateData.rewardType == 1)
        ) {
            // Check if rewardToken is updated,
            ICapxCommunityQuest(communityAddress).updateRewards(
                _msgSender(),
                currentDetails.questNumber,
                _rewardUpdateData.totalRewardAmountInWei,
                _rewardUpdateData.maxRewardAmountInWei
            );
        }
    }

    function handleReputationRewards(
        string memory _questId,
        uint256 _newRewardType,
        RewardTypeDTO calldata _rewardUpdateData
    ) internal {
        if (_newRewardType == 1) {
            capxReputationScore.disableQuest(_questId);
        } else {
            capxReputationScore.setQuestDetails(
                ICapxReputationScore.QuestDTO({
                    communityQuestId: _questId,
                    reputationType: _rewardUpdateData.reputationType,
                    maxReputationScore: _rewardUpdateData.maxReputationScore
                })
            );
        }
    }

    function predictCommunityAddress(
        string calldata _communityId
    ) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(_communityId));
        return Clones.predictDeterministicAddress(capxCommunityQuest, salt);
    }

    function setClaimSignerAddress(
        address _claimSignerAddress
    ) public onlyOwner {
        if (_claimSignerAddress == address(0)) revert ZeroAddressNotAllowed();
        claimSignerAddress = _claimSignerAddress;
    }

    function setCapxTokenForger(address _capxTokenForger) public onlyOwner {
        if (_capxTokenForger == address(0)) revert ZeroAddressNotAllowed();
        capxTokenForger = ICapxTokenForger(_capxTokenForger);
    }

    function setCapxCommunityQuestAddress(
        address _capxCommunityQuestAddress
    ) public onlyOwner {
        if (_capxCommunityQuestAddress == address(0))
            revert ZeroAddressNotAllowed();
        capxCommunityQuest = _capxCommunityQuestAddress;
    }

    function setCapxReputationContractAddress(
        address _capxReputationContractAddress
    ) public onlyOwner {
        if (_capxReputationContractAddress == address(0))
            revert ZeroAddressNotAllowed();

        capxReputationScore = ICapxReputationScore(
            _capxReputationContractAddress
        );
    }

    function updateCommunityOwner(
        address _oldOwner,
        address _newOwner
    ) external {
        if (!isCapxCommunity[_msgSender()]) revert NotAuthorized();
        string memory communityId = communityAddresstoId[_msgSender()];
        communityOwners[_newOwner] = communityOwners[_oldOwner];
        communityOwners[_oldOwner] = address(0);
        communityAuthorized[communityId][_oldOwner] = false;
        communityAuthorized[communityId][_newOwner] = true;
        communityOwner[communityId] = _newOwner;
    }

    function recoverSigner(
        bytes32 messagehash,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messagehash)
        );
        return ECDSAUpgradeable.recover(messageDigest, signature);
    }

    function addToAuthorized(
        string calldata _communityId,
        address account
    ) external onlyCommunityOwners(_communityId) {
        if (account == address(0)) revert ZeroAddressNotAllowed();
        if (communityAuthorized[_communityId][account] == true)
            revert AlreadyAuthorized();

        if (community[_communityId] != communityOwners[_msgSender()])
            revert NotAuthorized();
        communityAuthorized[_communityId][account] = true;
    }

    function removeFromAuthorized(
        string calldata _communityId,
        address account
    ) external onlyCommunityOwners(_communityId) {
        if (account == address(0)) revert ZeroAddressNotAllowed();
        if (communityOwner[_communityId] == account)
            revert CommunityOwnerCannotBeRemoved();
        if (communityAuthorized[_communityId][account] == false)
            revert AlreadyNotAuthorized();

        communityAuthorized[_communityId][account] = false;
    }

    function disableQuest(
        string calldata _communityId,
        uint256 _questNumber
    ) external nonReentrant onlyCommunityAuthorized(_communityId) {
        string memory _questId = getQuestId(_communityId, _questNumber);

        if (isCapxCommunityQuest[_questId] == address(0))
            revert InvalidQuestNumber();

        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questId
        ];

        if (currCapxQuest.active == false) revert QuestAlreadyDisabled();

        currCapxQuest.active = false;
    }

    function disableTask(
        uint256 _taskNumber
    ) external onlyCapxCommunityAuthorized {
        string memory _taskId = string(
            abi.encodePacked(capxCommunityId, ":", uintToStr(_taskNumber))
        );
        if (isCapxTask[_taskId] == false) revert TaskIdDoesNotExist();

        CapxTaskDetails storage currCapxTask = taskDetails[_taskId];

        if (currCapxTask.active == false) revert TaskAlreadyDisabled();

        currCapxTask.active = false;
    }

    function enableQuest(
        string calldata _communityId,
        uint256 _questNumber
    ) external nonReentrant onlyCommunityAuthorized(_communityId) {
        string memory _questId = getQuestId(_communityId, _questNumber);

        if (isCapxCommunityQuest[_questId] == address(0))
            revert InvalidQuestNumber();

        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questId
        ];

        if (currCapxQuest.active == true) revert QuestAlreadyActive();

        currCapxQuest.active = true;
    }

    function enableTask(uint256 _taskNumber) external onlyCapxCommunityAuthorized {
        string memory _taskId = string(
            abi.encodePacked(capxCommunityId, ":", uintToStr(_taskNumber))
        );
        if (isCapxTask[_taskId] == false) revert TaskIdDoesNotExist();
        CapxTaskDetails storage currCapxTask = taskDetails[_taskId];

        if (currCapxTask.active == true) revert TaskAlreadyEnabled();

        currCapxTask.active = false;
    }

    function extendQuest(
        string calldata _communityId,
        uint256 _questNumber,
        uint256 _endTime
    ) external nonReentrant onlyCommunityAuthorized(_communityId) {
        string memory _questId = getQuestId(_communityId, _questNumber);

        if (_endTime <= block.timestamp) revert InvalidEndTime();
        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questId
        ];
        currCapxQuest.endTime = _endTime;
    }

    function getQuestIdAndContractAddress(
        string calldata _communityId,
        uint256 _questNumber
    ) internal view returns (address, string memory) {
        address _communityAddress = community[_communityId];

        string memory _questId = string(
            abi.encodePacked(_communityId, "_", uintToStr(_questNumber))
        );

        if (isCapxCommunityQuest[_questId] == address(0))
            revert QuestIdDoesNotExist();

        return (_communityAddress, _questId);
    }

    function getQuestId(
        string calldata _communityId,
        uint256 _questNumber
    ) internal view returns (string memory) {
        string memory _questId = string(
            abi.encodePacked(_communityId, "_", uintToStr(_questNumber))
        );

        if (isCapxCommunityQuest[_questId] == address(0))
            revert QuestIdDoesNotExist();
        return (_questId);
    }

    function withdrawQuestRewards(
        string calldata _communityId,
        uint256 _questNumber
    ) external nonReentrant onlyCommunityAuthorized(_communityId) {
        string memory _questId = getQuestId(_communityId, _questNumber);
        address _communityAddress = isCapxCommunityQuest[_questId];
        if (_communityAddress == address(0)) revert InvalidQuestNumber();

        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questId
        ];
        if (currCapxQuest.active == true) revert QuestMustBeDisabled();
        if (currCapxQuest.rewardType != 1 && currCapxQuest.rewardType != 3)
            revert InvalidRewardType();
        ICapxCommunityQuest(_communityAddress).withdrawQuestRewards(
            _questNumber
        );
    }

    function withdrawAllQuestRewards(
        string calldata _communityId
    ) external nonReentrant onlyCommunityOwners(_communityId) {
        address communityAddress = community[_communityId];
        for (
            uint256 _questNumber = 1;
            _questNumber <= communityQuestCount[_communityId];
            _questNumber++
        ) {
            string memory _questId = getQuestId(_communityId, _questNumber);
            CapxQuestDetails storage currCapxQuest = communityQuestDetails[
                _questId
            ];
            currCapxQuest.active = false;
        }
        ICapxCommunityQuest(communityAddress).withdrawAllQuestRewards();
    }

    function withdrawETH(
        string calldata _communityId
    ) external nonReentrant onlyCommunityOwners(_communityId) {
        address communityAddress = community[_communityId];
        ICapxCommunityQuest(communityAddress).withdrawETH(_msgSender());
    }

    function toggleCommunityActive(
        string calldata _communityId
    )
        external
        onlyCommunityAuthorized(_communityId)
        returns (bool isCommunityActive)
    {
        address communityAddress = community[_communityId];
        bool _isCommunityActive = ICapxCommunityQuest(communityAddress)
            .toggleCommunityActive();
        return _isCommunityActive;
    }
}
