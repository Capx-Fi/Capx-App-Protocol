# CapxQuestForger

The `CapxQuestForger` contract is designed to forge or create quests within the Capx ecosystem. It provides functionalities to create different types of quests, manage quest parameters, and handle quest-related operations.

## Overview

The contract integrates with various OpenZeppelin upgradeable contracts for enhanced security and modularity. It also interacts with other custom contracts like `CapxBasicQuest`, `CapxDailyQuest`, and various interfaces to provide a comprehensive quest management system.

## Modifiers

### initializer

Ensures that certain functions can only be called during the contract's initialization phase.

## Methods

### initialize

```solidity
function initialize(
    address _claimSignerAddress,
    address _feeReceiver,
    address _capxBasicQuestAddress,
    address _capxDailyQuestAddress,
    address _owner,
    address _capxTokenForger
) external initializer;
```

**Description:**  
Initializes the contract with essential parameters like addresses for claim signing, fee receiving, basic and daily quests, the contract owner, and the token forger.

### pause, unPause

```solidity
function pause() public onlyOwner whenNotPaused;
function unPause() public onlyOwner whenPaused;
```

**Description:**  
Allows the contract owner to pause or unpause the contract, halting or resuming its operations.

### uintToStr

```solidity
function uintToStr(uint256 value) internal pure returns (string memory);
```

**Description:**  
Converts a uint256 value to its string representation.

### createQuest

```solidity
function createQuest(
    CreateQuest memory quest
) external onlyOwner whenNotPaused returns (address);
```

**Description:**  
Creates a new quest based on the provided parameters and returns the address of the newly created quest.

### setCapxBasicQuestAddress, setCapxDailyQuestAddress, setCapxTokenForger, setClaimSignerAddress, setFeeReceiver, setQuestFee

```solidity
function setCapxBasicQuestAddress(address _capxBasicQuestAddress) public onlyOwner;
function setCapxDailyQuestAddress(address _capxDailyQuestAddress) public onlyOwner;
function setCapxTokenForger(address _capxTokenForger) public onlyOwner;
function setClaimSignerAddress(address _claimSignerAddress) public onlyOwner;
function setFeeReceiver(address _feeReceiver) public onlyOwner;
function setQuestFee(uint16 _questFee) public onlyOwner;
```

**Description:**  
These functions allow the contract owner to update various contract parameters, including addresses for basic and daily quests, the token forger, the claim signer, the fee receiver, and the quest fee.

### setCommunityOwner, updateCommunityReward

```solidity
function setCommunityOwner(
    string memory _communityId,
    address _owner
) external;
function updateCommunityReward(
    string memory _communityId,
    address _rewardToken,
    bool _active
) external;
```

**Description:**  
Allows authorized users to set or update the owner of a community and manage the reward tokens associated with a community.

### getClaimedNumber

```solidity
function getClaimedNumber(string memory _questId) external view returns(uint);
```

**Description:**  
Returns the number of claims made for a specific quest.

### predictBasicQuestAddress, predictDailyQuestAddress

```solidity
function predictBasicQuestAddress(string calldata _communityId, uint256 _questNumber) external view returns(address);
function predictDailyQuestAddress(string calldata _communityId, uint256 _questNumber) external view returns(address);
```

**Description:**  
Predicts the address of a basic or daily quest based on the community ID and quest number.

### claim

```solidity
function claim(
    bytes32 _messageHash,
    bytes memory _signature,
    string memory _questId,
    address _receiver,
    uint256 _timestamp,
    uint256 _rewardAmount
) external whenNotPaused;
```

**Description:**  
Allows users to claim rewards for a specific quest.

### emitClaim

```solidity
function emitClaim(
    address _questAddress,
    string memory _questId,
    string memory _questType,
    address _claimer,
    address _claimReceiver,
    uint256 _timestamp,
    address _rewardToken,
    uint256 _rewardAmount
) external;
```

**Description:**  
Emits a claim event when a user claims a reward for a quest.

### questInfo

```solidity
function questInfo(string memory questId_) external view returns (address, uint, uint);
```

**Description:**  
Provides information about a specific quest, including its address, maximum participants, and the current participant count.

## Events

### CapxQuestCreated

```solidity
event CapxQuestCreated(
    address indexed creator,
    address indexed questAddress,
    string questType,
    string questId,
    string questRewardType,
    address rewardToken,
    uint256 startTime,
    uint256 endTime,
    uint256 maxParticipants,
    uint256 rewardAmountInWei
);
```

**Description:**  
Emitted when a new quest is created in the system.

### CapxQuestRewardClaimed

```solidity
event CapxQuestRewardClaimed(
    address indexed questAddress,
    string questId,
    string questType,
    address claimer,
    address claimReceiver,
    uint256 timestamp,
    address rewardToken,
    uint256 rewardAmount


);
```

**Description:**  
Emitted when a user claims a reward for a quest.

---
