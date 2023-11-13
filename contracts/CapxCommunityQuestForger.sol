//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
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

contract CapxCommunityQuestForger is Initializable, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable, ICapxCommunityQuestForger {
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

    mapping(string => address) public isCapxCommunityQuest;
    mapping(address => bool) public isCapxCommunity;
    mapping(string => address) public community;
    mapping(string => address) public communityOwner;
    mapping(string => uint256) public communityQuestCount;


    constructor() initializer {}

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
        require(community[_communityId] == address(0), "Community Already Exists");
        bytes32 salt = keccak256(abi.encodePacked(_communityId));
        address communityAddress = Clones.cloneDeterministic(capxCommunityQuest, salt);
        community[_communityId] = communityAddress;
        communityOwner[_communityId] = _msgSender();
        isCapxCommunity[communityAddress] = true;
        CapxCommunityQuest(communityAddress).initialize(
            _owner,
            _communityId
        );
    }

    function createQuest(
        CreateQuest memory quest
    ) external onlyOwner whenNotPaused {
        if (quest.rewardToken == address(0)) revert ZeroAddressNotAllowed();
        require(capxTokenForger.isTokenPoweredByCapx(quest.rewardToken),"NOT Capx Generated Token");
        address communityAddress = community[quest.communityId];
        require(community[quest.communityId] != address(0), "Invalid Community Id");
        string memory _questId = string(abi.encodePacked(quest.communityId,"_",uintToStr(quest.questNumber)));
        // Create Quest.
        if(isCapxCommunityQuest[_questId] != address(0)) revert QuestIdUsed();
        // Initialise new Quest.
        {
            // Transfer tokens.
            ITokenPoweredByCapx(quest.rewardToken).addToWhitelist(communityAddress);
            IERC20(quest.rewardToken).safeTransferFrom(_msgSender(), communityAddress, quest.totalRewardAmountInWei);
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
        string memory _questId,
        address _receiver,
        uint256 _timestamp,
        uint256 _rewardAmount
    ) external whenNotPaused {
        address capxQuest = isCapxCommunityQuest[_questId];
        if (_receiver == address(0)) revert ZeroAddressNotAllowed();
        require(address(capxQuest) != address(0), "Invalid Capx Quest ID");
        ICapxCommunityQuest(capxQuest).claim(
            _messageHash,
            _signature,
            _questId,
            _receiver,
            _timestamp,
            _rewardAmount
        );
    }

    function emitClaim(
        address _communityAddress,
        string memory _questId,
        address _claimReceiver,
        uint256 _timestamp,
        address _rewardToken,
        uint256 _rewardAmount
    ) external {
        require(_msgSender() == _communityAddress, "NOT Authorized");
        require(isCapxCommunity[_msgSender()], "NOT Capx Quest");

        emit CapxCommunityQuestRewardClaimed(
            _msgSender(),
            _questId,
            _claimReceiver,
            _timestamp,
            _rewardToken,
            _rewardAmount
        );
    }

    function predictCommunityAddress(string calldata _communityId) external view returns(address) {
        bytes32 salt = keccak256(abi.encodePacked(_communityId));
        return Clones.predictDeterministicAddress(capxCommunityQuest,salt);
    }

    function setClaimSignerAddress(address _claimSignerAddress) public onlyOwner {
        if (_claimSignerAddress == address(0)) revert ZeroAddressNotAllowed();
        claimSignerAddress = _claimSignerAddress;
    }

    function setCapxTokenForger(address _capxTokenForger) public onlyOwner {
        if (_capxTokenForger == address(0)) revert ZeroAddressNotAllowed();
        capxTokenForger = ICapxTokenForger(_capxTokenForger);
    }

    function setCapxCommunityQuestAddress(address _capxCommunityQuestAddress) public onlyOwner {
        if (_capxCommunityQuestAddress == address(0)) revert ZeroAddressNotAllowed();
        capxCommunityQuest = _capxCommunityQuestAddress;
    }
}