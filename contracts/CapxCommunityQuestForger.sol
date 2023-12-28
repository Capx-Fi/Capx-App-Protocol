//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18 .0;
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

    struct CreateQuest {
        address rewardToken;
        uint256 startTime;
        uint256 endTime;
        uint256 maxParticipants;
        uint256 totalRewardAmountInWei;
        uint256 maxRewardAmountInWei;
        string communityId;
        uint256 questNumber;
        uint256 rewardType;
        uint256 reputationType;
        uint256 maxReputationScore;
    }

    struct CapxQuestDetails {
        string communityId;
        uint256 questNumber;
        uint256 startTime;
        uint256 endTime;
        uint256 maxParticipants;
        uint256 claimedParticipants;
        uint256 rewardType;
        bool active;
    }

    struct RewardTypeDTO {
        string communityId;
        uint256 questNumber;
        uint256 maxParticipants;
        uint256 rewardType;
    }

    address public claimSignerAddress;
    address public capxCommunityQuest;
    ICapxTokenForger public capxTokenForger;
    ICapxReputationScore public capxReputationScore;

    mapping(string => address) public isCapxCommunityQuest;
    mapping(address => bool) public isCapxCommunity;
    mapping(string => address) public community;
    mapping(address => address) private communityOwners;
    mapping(string => address) public communityOwner;
    mapping(address => string) private communityAddresstoId;
    mapping(string => uint256) public communityQuestCount;
    mapping(string => CapxQuestDetails) public communityQuestDetails; // questId -> CapxQuestDetails
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

        if (quest.rewardToken == address(0)) revert ZeroAddressNotAllowed();
        if (!capxTokenForger.isTokenPoweredByCapx(quest.rewardToken))
            revert NotCapxGeneratedToken();

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

    function updateIOURewards(
        string calldata _communityId,
        uint256 _questNumber,
        uint256 _newTotalRewardAmountInWei,
        uint256 _newMaxParticipants
    ) external onlyCommunityAuthorized(_communityId) nonReentrant {
        if (_newTotalRewardAmountInWei <= 0 || _newMaxParticipants <= 0)
            revert InvalidIOURewards();
        string memory _questId = getQuestId(_communityId, _questNumber);

        address communityAddress = isCapxCommunityQuest[_questId];

        CapxQuestDetails storage currentDetails = communityQuestDetails[
            _questId
        ];

        if (currentDetails.rewardType == 2) revert InvalidRewardType();

        bool _maxParticipantsIncreased = _newMaxParticipants >
            currentDetails.maxParticipants;

        ICapxCommunityQuest(communityAddress).updateTotalRewards(
            _msgSender(),
            _questNumber,
            _newTotalRewardAmountInWei,
            _maxParticipantsIncreased
        );
        currentDetails.maxParticipants = _newMaxParticipants;
    }

    function updateReputationRewards(
        string calldata _communityId,
        uint256 _questNumber,
        uint256 _newReputationType,
        uint256 _newMaxReputationScore
    ) external nonReentrant onlyCommunityOwners(_communityId) {
        string memory _questId = getQuestId(_communityId, _questNumber);

        CapxQuestDetails storage currentDetails = communityQuestDetails[
            _questId
        ];

        if (currentDetails.rewardType != 2 || currentDetails.rewardType != 3)
            revert InvalidRewardType();
        if (address(capxReputationScore) == address(0))
            revert CapxReputationContractNotInitalised();

        capxReputationScore.setQuestDetails(
            ICapxReputationScore.QuestDTO({
                communityQuestId: _questId,
                reputationType: _newReputationType,
                maxReputationScore: _newMaxReputationScore
            })
        );
    }

    function updateRewardType(
        RewardTypeDTO calldata _newRewards,
        bytes calldata _IOURewardsData,
        bytes calldata _ReputationRewardsData
    ) external nonReentrant onlyCommunityAuthorized(_newRewards.communityId) {
        string memory _questId = getQuestId(
            _newRewards.communityId,
            _newRewards.questNumber
        );

        CapxQuestDetails storage currentDetails = communityQuestDetails[
            _questId
        ];
        if (currentDetails.rewardType == _newRewards.rewardType)
            revert UseRewardTypeSpecificFunctions();
        ICapxCommunityQuest.QuestDTO memory _newIOURewards = abi.decode(
            _IOURewardsData,
            (ICapxCommunityQuest.QuestDTO)
        );
        ICapxReputationScore.QuestDTO memory _newReputationRewards = abi.decode(
            _ReputationRewardsData,
            (ICapxReputationScore.QuestDTO)
        );

        address communityAddress = community[_questId];

        handleIOURewards(
            communityAddress,
            _newRewards,
            currentDetails,
            _newIOURewards
        );
        handleReputationRewards(
            _questId,
            _newRewards.rewardType,
            currentDetails.rewardType,
            _newReputationRewards
        );
        currentDetails.maxParticipants = _newRewards.maxParticipants;
        currentDetails.rewardType = _newRewards.rewardType;
    }

    function handleIOURewards(
        address communityAddress,
        RewardTypeDTO memory _newRewards,
        CapxQuestDetails storage currentDetails,
        ICapxCommunityQuest.QuestDTO memory _newIOURewards
    ) internal {
        // Adding IOU Rewards (Switching to Reward Type 1 or 3 from 2)
        if (
            (currentDetails.rewardType == 2) &&
            (_newRewards.rewardType == 1 || _newRewards.rewardType == 3)
        ) {
            // Logic to transfer ERC20 tokens from the owner to the community contract
            ICapxCommunityQuest(communityAddress).setQuestDetails(
                _newIOURewards
            );
        }

        // Removing IOU Rewards (Switching from Reward Type 1 or 3 to 2)
        if (
            (currentDetails.rewardType == 1 ||
                currentDetails.rewardType == 3) && _newRewards.rewardType == 2
        ) {
            // Logic to transfer ERC20 tokens from the community contract back to the owner
            ICapxCommunityQuest(communityAddress).disableQuest(
                _newIOURewards.questNumber
            );
        }

        // Switching from 1 to 3 or 3 to 1
        if (
            (currentDetails.rewardType == 1 ||
                currentDetails.rewardType == 3) &&
            (_newRewards.rewardType == 3 || _newRewards.rewardType == 1)
        ) {
            bool _maxParticipantsIncreased = _newRewards.maxParticipants >
                currentDetails.maxParticipants;

            ICapxCommunityQuest(communityAddress).updateTotalRewards(
                _msgSender(),
                currentDetails.questNumber,
                _newIOURewards.totalRewardAmountInWei,
                _maxParticipantsIncreased
            );
        }
    }

    function handleReputationRewards(
        string memory _questId,
        uint256 _newRewardType,
        uint256 _oldRewardType,
        ICapxReputationScore.QuestDTO memory _newReputationRewards
    ) internal {
        if (_oldRewardType == 1 && _newRewardType == 2) {
            capxReputationScore.setQuestDetails(_newReputationRewards);
        } else if (_oldRewardType == 2 && _newRewardType == 1) {
            capxReputationScore.setQuestDetails(
                ICapxReputationScore.QuestDTO({
                    communityQuestId: _questId,
                    reputationType: 0,
                    maxReputationScore: 0
                })
            );
        } else if (_oldRewardType == 2 && _newRewardType == 3) {
            capxReputationScore.setQuestDetails(_newReputationRewards);
        } else if (_oldRewardType == 3 && _newRewardType == 1) {
            capxReputationScore.setQuestDetails(
                ICapxReputationScore.QuestDTO({
                    communityQuestId: _questId,
                    reputationType: 0,
                    maxReputationScore: 0
                })
            );
        } else if (_oldRewardType == 3 && _newRewardType == 2) {
            capxReputationScore.setQuestDetails(_newReputationRewards);
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
        (
            address _communityAddress,
            string memory _questId
        ) = getQuestIdAndContractAddress(_communityId, _questNumber);

        if (isCapxCommunityQuest[_questId] == address(0))
            revert InvalidQuestNumber();

        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questId
        ];

        if (currCapxQuest.active == false) revert QuestAlreadyDisabled();

        if (currCapxQuest.rewardType == 1 || currCapxQuest.rewardType == 3) {
            ICapxCommunityQuest(_communityAddress).disableQuest(_questNumber);
        }
        currCapxQuest.active = false;
    }

    function enableQuest(
        string calldata _communityId,
        uint256 _questNumber
    ) external nonReentrant onlyCommunityAuthorized(_communityId) {
        (
            address _communityAddress,
            string memory _questId
        ) = getQuestIdAndContractAddress(_communityId, _questNumber);

        if (isCapxCommunityQuest[_questId] == address(0))
            revert InvalidQuestNumber();

        CapxQuestDetails storage currCapxQuest = communityQuestDetails[
            _questId
        ];

        if (currCapxQuest.active == true) revert QuestAlreadyActive();

        if (currCapxQuest.rewardType == 1 || currCapxQuest.rewardType == 3) {
            ICapxCommunityQuest(_communityAddress).enableQuest(_questNumber);
        }

        currCapxQuest.active = true;
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

    function withdrawTokens(
        string calldata _communityId,
        address[] memory tokens
    ) external nonReentrant onlyCommunityOwners(_communityId) {
        address communityAddress = community[_communityId];
        ICapxCommunityQuest(communityAddress).withdrawTokens(tokens);
    }
}
