//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CapxCommunityQuest} from "./CapxCommunityQuest.sol";
import {ICapxCommunityQuest} from "./interfaces/ICapxCommunityQuest.sol";
import {ICapxCommunityQuestForger} from "./interfaces/ICapxCommunityQuestForger.sol";
import {ITokenPoweredByCapx} from "./interfaces/ITokenPoweredByCapx.sol";
import {ICapxTokenForger} from "./interfaces/ICapxTokenForger.sol";

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {ICapxReputationScore} from "./interfaces/ICapxReputationScore.sol";

contract CapxCommunityQuestForger is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
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
    }

    address public claimSignerAddress;
    address public capxCommunityQuest;
    ICapxTokenForger public capxTokenForger;
    ICapxReputationScore public capxReputationScore;

    mapping(string => address) public isCapxCommunityQuest;
    mapping(address => bool) public isCapxCommunity;
    mapping(string => address) public community;
    mapping(address => bool) private communityOwners;
    mapping(string => address) public communityOwner;
    mapping(address => string) private communityAddresstoId;
    mapping(string => uint256) public communityQuestCount;


    constructor() initializer {}

    modifier onlyAuthorized() {
        require(
            owner() == _msgSender() || communityOwners[_msgSender()],
            "CapxCommunityQuestForger: Caller NOT Authorized."
        );
        _;
    }

    function _authorizeUpgrade(address _newImplementation)
        internal
        override
        onlyOwner
    {}

    function initialize(
        address _claimSignerAddress,
        address _capxCommunityQuest,
        address _owner,
        address _capxTokenForger
    ) external initializer {
        if (_claimSignerAddress == address(0)) revert ZeroAddressNotAllowed();
        if (_capxTokenForger == address(0)) revert ZeroAddressNotAllowed();
        if (_owner == address(0)) revert ZeroAddressNotAllowed();
        if (_capxCommunityQuest == address(0)) revert ZeroAddressNotAllowed();

        __Ownable_init();
        __Pausable_init();
        _transferOwnership(_owner);

        claimSignerAddress = _claimSignerAddress;
        capxTokenForger = ICapxTokenForger(_capxTokenForger);
        capxCommunityQuest = _capxCommunityQuest;
    }

    function updateCapxReputationScoreAddress(address _capxReputationScore)
        external
    {
        if (_capxReputationScore == address(0)) revert ZeroAddressNotAllowed();
        capxReputationScore = ICapxReputationScore(_capxReputationScore);
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

    function createCommunity(address _owner, string memory _communityId)
        external
        onlyOwner
        whenNotPaused
    {
        if (_owner == address(0)) revert ZeroAddressNotAllowed();
        if (communityOwners[_owner] == true) revert OwnerOwnsACommunity();
        require(
            community[_communityId] == address(0),
            "CapxCommunityQuestForger: Community Already Exists"
        );
        bytes32 salt = keccak256(abi.encodePacked(_communityId));
        address communityAddress = Clones.cloneDeterministic(
            capxCommunityQuest,
            salt
        );
        community[_communityId] = communityAddress;
        communityOwner[_communityId] = _owner;
        communityOwners[_owner] = true;
        isCapxCommunity[communityAddress] = true;
        communityAddresstoId[communityAddress] = _communityId;
        CapxCommunityQuest(communityAddress).initialize(_owner, _communityId);
    }

    function createQuest(CreateQuest memory quest)
        external
        onlyOwner
        whenNotPaused
    {
        if (quest.rewardToken == address(0)) revert ZeroAddressNotAllowed();
        require(
            capxTokenForger.isTokenPoweredByCapx(quest.rewardToken),
            "CapxCommunityQuestForger: NOT Capx Generated Token"
        );
        address communityAddress = community[quest.communityId];
        require(
            community[quest.communityId] != address(0),
            "CapxCommunityQuestForger: Invalid Community Id"
        );
        string memory _questId = string(
            abi.encodePacked(
                quest.communityId,
                "_",
                uintToStr(quest.questNumber)
            )
        );
        // Create Quest.
        if (isCapxCommunityQuest[_questId] != address(0)) revert QuestIdUsed();
        // Initialise new Quest.
        {
            // Transfer tokens.
            ITokenPoweredByCapx(quest.rewardToken).addToWhitelist(
                communityAddress
            );
            IERC20(quest.rewardToken).safeTransferFrom(
                _msgSender(),
                communityAddress,
                quest.totalRewardAmountInWei
            );
        }

        // Create Quest.
        CapxCommunityQuest(communityAddress).createQuest(
            quest.startTime,
            quest.endTime,
            quest.rewardToken,
            quest.questNumber,
            quest.maxParticipants,
            quest.totalRewardAmountInWei,
            quest.maxRewardAmountInWei
        );

        isCapxCommunityQuest[_questId] = communityAddress;
        communityQuestCount[quest.communityId] += 1;
    }

    function claim(
        bytes32 _messageHash,
        bytes memory _signature,
        bytes calldata _claimData
    ) external whenNotPaused {
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
        require(
            address(capxQuest) != address(0),
            "CapxCommunityQuestForger: Invalid Capx Quest ID"
        );

        if (_rewardType == 1) {
            ICapxCommunityQuest(capxQuest).claim(
                _questId,
                _msgSender(),
                _timestamp,
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
                _questId,
                _msgSender(),
                _timestamp,
                _repType,
                _repScore
            );
        } else if (_rewardType == 3) {
            ICapxCommunityQuest(capxQuest).claim(
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
            emit CapxReputationScoreClaimed(
                _questId,
                _msgSender(),
                _timestamp,
                _repType,
                _repScore
            );
        }else{
            revert InvalidRewardType();
        }
    }

    function emitClaim(
        address _communityAddress,
        string memory _questId,
        address _claimReceiver,
        uint256 _timestamp,
        address _rewardToken,
        uint256 _rewardAmount
    ) external {
        require(_msgSender() == _communityAddress, "CapxCommunityQuestForger: NOT Authorized");
        require(isCapxCommunity[_msgSender()], "CapxCommunityQuestForger: NOT Capx Quest");

        emit CapxCommunityQuestRewardClaimed(
            _msgSender(),
            _questId,
            _claimReceiver,
            _timestamp,
            _rewardToken,
            _rewardAmount
        );
    }

    function predictCommunityAddress(string calldata _communityId)
        external
        view
        returns (address)
    {
        bytes32 salt = keccak256(abi.encodePacked(_communityId));
        return Clones.predictDeterministicAddress(capxCommunityQuest, salt);
    }

    function setClaimSignerAddress(address _claimSignerAddress)
        public
        onlyOwner
    {
        if (_claimSignerAddress == address(0)) revert ZeroAddressNotAllowed();
        claimSignerAddress = _claimSignerAddress;
    }

    function setCapxTokenForger(address _capxTokenForger) public onlyOwner {
        if (_capxTokenForger == address(0)) revert ZeroAddressNotAllowed();
        capxTokenForger = ICapxTokenForger(_capxTokenForger);
    }

    function setCapxCommunityQuestAddress(address _capxCommunityQuestAddress)
        public
        onlyOwner
    {
        if (_capxCommunityQuestAddress == address(0))
            revert ZeroAddressNotAllowed();
        capxCommunityQuest = _capxCommunityQuestAddress;
    }

    function updateCommunityOwner(address _oldOwner, address _newOwner)
        external
    {
        require(isCapxCommunity[_msgSender()], "CapxCommunityQuestForger: NOT Capx Quest");
        string memory communityId = communityAddresstoId[_msgSender()];
        communityOwners[_oldOwner] = false;
        communityOwners[_newOwner] = true;
        communityOwner[communityId] = _newOwner;
    }

    function recoverSigner(bytes32 messagehash, bytes memory signature)
        public
        pure
        returns (address)
    {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messagehash)
        );
        return ECDSAUpgradeable.recover(messageDigest, signature);
    }
}
