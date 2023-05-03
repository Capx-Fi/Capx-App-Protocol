//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface ICapxQuest {

    event Started(uint timestamp);
    
    error AlreadyClaimed();
    error NoRewardsToClaim();
    error InvalidEndTime();
    error InvalidStartTime();
    error QuestNotStarted();
    error QuestActiveNoWithdraw();
    error TotalRewardsExceedsAvailableBalance();
    error QuestNotActive();
    error ChildImplementationMissing();
    error InvalidSigner();
    error InvalidMessageHash();
    error QuestEnded();
    error OverMaxParticipants();

    function getRewardAmount() external view returns (uint256);
    function getRewardToken() external view returns (address);

    function claim(
        bytes32 _messageHash,
        bytes memory _signature,
        address _sender,
        address _receiver,
        uint256 _timestamp,
        uint256 _rewardAmount
    ) external;
}