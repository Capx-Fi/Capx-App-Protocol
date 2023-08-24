# CapxQuest

The `CapxQuest` contract serves as a base contract for creating and managing quests within the Capx ecosystem. It provides functionalities to initialize quests, manage quest parameters, and handle quest-related operations.

## Overview

The contract integrates with various OpenZeppelin contracts for enhanced security and modularity. It also interacts with the `ICapxQuest` and `ICapxQuestForger` interfaces to provide a comprehensive quest management system.

## Modifiers

### onlyInitializing

Ensures that certain functions can only be called during the contract's initialization phase.

### withdrawAllowed

Ensures that certain functions can only be called after the quest has ended.

### isStarted

Ensures that the quest has started.

### isQuestActive

Ensures that the quest is currently active.

## Methods

### questInit

```solidity
function questInit(
    address _rewardToken,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _maxParticipants,
    uint256 _rewardAmountInWei,
    string memory _questId
) public onlyInitializing;
```

**Description:**  
Initializes the quest with the specified parameters.

### start

```solidity
function start() public virtual onlyOwner;
```

**Description:**  
Starts the quest and emits event Started

`emit Started(block.timestamp);`.

### pause, unPause

```solidity
function pause() external onlyOwner whenNotPaused;
function unPause() external onlyOwner whenPaused;
```

**Description:**  
Allows the contract owner to pause or unpause the quest, halting or resuming its operations.

### recoverSigner

```solidity
function recoverSigner(bytes32 messagehash, bytes memory signature) public pure returns (address);
```

**Description:**  
Recovers the signer's address from the provided message hash and signature.

### claim

```solidity
function claim(
    bytes32 _messageHash,
    bytes memory _signature,
    address _sender,
    address _receiver,
    uint256 _timestamp,
    uint256 _rewardAmount
) external virtual nonReentrant isQuestActive whenNotPaused;
```

**Description:**  
Allows participants to claim their rewards. This function is virtual and requires implementation in child contracts.

### _calculateRedeemableTokens, _calculateRewards, _transferRewards

```solidity
function _calculateRedeemableTokens() internal virtual returns (uint256);
function _calculateRewards(uint256 _redeemableTokens) internal virtual returns (uint256);
function _transferRewards(address _claimer, uint256 _rewardAmount) internal virtual;
```

**Description:**  
These are internal virtual functions that require implementation in child contracts to calculate redeemable tokens, rewards, and transfer rewards.

### getRewardAmount, getRewardToken

```solidity
function getRewardAmount() external view returns (uint256);
function getRewardToken() external view returns (address);
```

**Description:**  
Returns the reward amount and reward token address, respectively.

### recoverToken

```solidity
function recoverToken(address _tokenAddress) external nonReentrant onlyOwner;
```

**Description:**  
Allows the contract owner to recover any ERC20 tokens mistakenly sent to the contract, except for the reward token.

### updateRewardAmountInWei

```solidity
function updateRewardAmountInWei(
    uint256 _rewardAmountInWei
) external nonReentrant onlyOwner;
```

**Description:**  
Allows the contract owner to update the reward amount in Wei.

### updateTotalParticipants

```solidity
function updateTotalParticipants(
    uint256 _maxParticipants
) external nonReentrant onlyOwner;
```

**Description:**  
Allows the contract owner to update the total number of participants for the quest.

### extendQuest

```solidity
function extendQuest(
    uint256 _endTime
) external nonReentrant onlyOwner;
```

**Description:**  
Allows the contract owner to extend the quest's end time.

## Events

### Started

```solidity
event Started(uint256 timestamp);
```

**Description:**  
Emitted when the quest starts.

---