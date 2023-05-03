//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CapxQuest} from "./CapxQuest.sol";

contract CapxDailyIOUQuest is CapxQuest {
    using SafeERC20 for IERC20;

    uint16 public questFee;
    bool public hasWithdrawn;
    address public feeReceiver;

    mapping(address => mapping(uint256 => bool)) private claimedUsers;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _rewardToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _maxParticipants,
        uint256 _rewardAmountInWei,
        string memory _questId,
        uint16 _questFee,
        address _feeReceiver
    ) external initializer {
        super.questInit(
            _rewardToken,
            _startTime,
            _endTime,
            _maxParticipants,
            _rewardAmountInWei,
            _questId
        );

        questFee = _questFee;
        hasWithdrawn = false;
        feeReceiver = _feeReceiver;
        started = true;
    }


    modifier onlyFeeReceiverOrOwner() {
        require(msg.sender == owner() || msg.sender == feeReceiver, "Not Authorized.");
        _;
    }

    function totalRewards() external view returns (uint256) {
        return maxParticipants * rewardAmountInWei;
    }

    function protocolReward() external view returns (uint256) {
        return (this.totalRewards() * questFee) / 10_000;
    }

    function start() public override {
        if (
            IERC20(rewardToken).balanceOf(address(this)) < (this.totalRewards() + this.protocolReward())
        ) revert TotalRewardsExceedsAvailableBalance();
        super.start();
    }

    function claim(
        bytes32 _messageHash,
        bytes memory _signature,
        address _sender,
        address _receiver,
        uint256 _timestamp,
        uint256 _rewardAmount
    ) external virtual override nonReentrant isQuestActive whenNotPaused {
        require(msg.sender == address(capxQuestForger),"NOT Authorized to call.");
        require(_timestamp < block.timestamp, "Cannot Claim Future Rewards");
        if (participantCount + 1 > maxParticipants) revert OverMaxParticipants();
        if (claimedUsers[_sender][_timestamp] == true) revert AlreadyClaimed();
        if (!started) revert QuestNotStarted();
        if (block.timestamp < startTime) revert QuestNotStarted();
        if (block.timestamp > endTime) revert QuestEnded();
        if (keccak256(abi.encodePacked(_sender,_receiver,questId,_timestamp,_rewardAmount)) != _messageHash) revert InvalidMessageHash();
        if (recoverSigner(_messageHash, _signature) != capxQuestForger.claimSignerAddress()) revert InvalidSigner();

        claimedUsers[_sender][_timestamp] = true;
        claimedUsers[_receiver][_timestamp] = true;
        ++participantCount;

        uint256 rewards = _calculateRewards(_rewardAmount);
        _transferRewards(_receiver, rewards);

        claimedTokenAmt += rewards;

        capxQuestForger.emitClaim(
            address(this), 
            questId,
            "daily_iou", 
            _sender, 
            _receiver, 
            _timestamp, 
            rewardToken, 
            rewards
        );
    }

    function _calculateRedeemableTokens() internal pure override returns (uint256) {
        return 1;
    }

    function _transferRewards(address _claimer, uint256 _amount) internal override {
        require(IERC20(rewardToken).approve(_claimer, _amount));
        IERC20(rewardToken).safeTransfer(_claimer, _amount);
    }

    function _calculateRewards(uint256 _redeemableTokens) internal view override returns (uint256) {
        return _redeemableTokens * rewardAmountInWei;
    }

    function protocolFee() external view returns (uint256) {
        return (participantCount * rewardAmountInWei * questFee) / 10_000;
    }

    function withdrawLeftOverRewards() external onlyFeeReceiverOrOwner nonReentrant() withdrawAllowed {
        require(!hasWithdrawn, "Already Withdrawn");

        uint unclaimedTokens = (maxParticipants - participantCount) * rewardAmountInWei;
        uint256 nonClaimableTokens = IERC20(rewardToken).balanceOf(address(this)) - this.protocolFee() - unclaimedTokens;

        hasWithdrawn = true;

        IERC20(rewardToken).safeTransfer(owner(), nonClaimableTokens);
        IERC20(rewardToken).safeTransfer(feeReceiver, this.protocolFee());
    }

    function isClaimed(address _addressInScope, uint256 _timestamp) external view returns (bool) {
        return claimedUsers[_addressInScope][_timestamp];
    }
}