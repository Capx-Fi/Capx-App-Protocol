//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CapxQuest} from "./CapxQuest.sol";

contract CapxIOUQuest is CapxQuest {
    using SafeERC20 for IERC20;

    uint16 public questFee;
    bool public hasWithdrawn;
    address public feeReceiver;

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

    function withdrawLeftOverRewards() external onlyFeeReceiverOrOwner withdrawAllowed {
        require(!hasWithdrawn, "Already Withdrawn");

        uint unclaimedTokens = (maxParticipants - participantCount) * rewardAmountInWei;
        uint256 nonClaimableTokens = IERC20(rewardToken).balanceOf(address(this)) - this.protocolFee() - unclaimedTokens;

        hasWithdrawn = true;

        IERC20(rewardToken).safeTransfer(owner(), nonClaimableTokens);
        IERC20(rewardToken).safeTransfer(feeReceiver, this.protocolFee());
    }
}