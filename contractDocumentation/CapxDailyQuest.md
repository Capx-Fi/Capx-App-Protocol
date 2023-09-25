# CapxDailyQuest

The `CapxDailyQuest` contract, inherited from the `CapxQuest` contract, is designed to handle daily quests within the Capx ecosystem. It provides additional functionalities specific to daily quests, such as managing quest fees and handling rewards on a daily basis.

## Overview

The contract integrates with OpenZeppelin's `SafeERC20` library for safe ERC20 token operations. It inherits from the `CapxQuest` contract, which provides foundational quest functionalities. Additionally, the contract utilizes ECDSA (Elliptic Curve Digital Signature Algorithm) for signature verification to ensure the authenticity of reward claims.

## Modifiers

### onlyFeeReceiverOrOwner

Ensures that certain functions can only be called by the contract owner or the designated fee receiver.

## Methods

### Constructor:

```solidity
constructor() {
    _disableInitializers();
}
```

**Description:**  
This constructor disables the initializers, ensuring that the contract's initialization functions can only be called once.

### initialize

```solidity
function initialize(
    address _rewardToken,
    uint256 _startTime,
    uint256 _endTime,
    uint256 _maxParticipants,
    uint256 _rewardAmountInWei,
    string memory _questId,
    uint16 _questFee,
    address _feeReceiver
) external initializer;
```

**Description:**  
Initializes the daily quest with the specified parameters.

### totalRewards

```solidity
function totalRewards() external view returns (uint256);
```

**Description:**  
Returns the total rewards for the quest, calculated as the product of the maximum number of participants and the reward amount in Wei.

### protocolReward

```solidity
function protocolReward() external view returns (uint256);
```

**Description:**  
Calculates and returns the protocol's reward based on the total rewards and the quest fee.

### start

```solidity
function start() public override;
```

**Description:**  
Starts the quest. It ensures that the contract has enough balance to cover the total rewards and the protocol reward before starting.

### claim

```solidity
function claim(
    bytes32 _messageHash,
    bytes memory _signature,
    address _sender,
    address _receiver,
    uint256 _timestamp,
    uint256 _rewardAmountInWei
) external virtual override nonReentrant isQuestActive whenNotPaused;
```

**Description:**  
The `claim` function allows participants to claim their rewards for the daily quest. It ensures the validity of the claim and then disburses the rewards. The function uses ECDSA to verify the provided signature against a known public key (or address in Ethereum's context). If the signature is valid, the claim is processed; otherwise, it's rejected.

**Parameters:**

- `_messageHash`: A hash representing the claim details.
- `_signature`: A signature that proves the authenticity of the claim.
- `_sender`: The address initiating the claim.
- `_receiver`: The address that will receive the rewards.
- `_timestamp`: The timestamp of the claim.
- `_rewardAmountInWei`: The amount of reward being claimed.

**Functionality:**

1. The function first checks if the caller is authorized, ensuring it's the `capxQuestForger`.
2. It then verifies the timestamp of the claim to ensure it's not from the future.
3. The function checks if the maximum participants limit has been reached.
4. It ensures that the `_receiver` hasn't already claimed the reward for the given timestamp.
5. The function checks if the quest has started and if it's still active.
6. **ECDSA Verification:** The function uses ECDSA to verify the integrity of the `_messageHash` using the provided `_signature`. This ensures that the claim was genuinely signed by the expected private key.
7. The function ensures that the signer of the `_messageHash` (verified using ECDSA) is the authorized `claimSignerAddress` from the `capxQuestForger`.
8. After all checks pass, the `_receiver` is marked as having claimed the reward for the given timestamp.
9. The participant count is incremented.
10. The rewards are calculated and then transferred to the `_receiver`.
11. The total claimed token amount is updated.

**Event Emission:**

The function emits a `emitClaim` event from the `capxQuestForger` contract. This event logs the details of the claim, providing a transparent record of all successful claims.

```solidity
capxQuestForger.emitClaim(
    address(this),
    questId,
    "daily_quest",
    _sender,
    _receiver,
    _timestamp,
    rewardToken,
    rewards
);
```

**Parameters of the `emitClaim` event:**

- `address(this)`: The address of the `CapxDailyQuest` contract.
- `questId`: The ID of the quest.
- `daily_quest`: A string indicating the type of quest.
- `_sender`: The address initiating the claim.
- `_receiver`: The address that received the rewards.
- `_timestamp`: The timestamp of the claim.
- `rewardToken`: The address of the reward token.
- `rewards`: The amount of reward disbursed.

### _calculateRedeemableTokens

```solidity
function _calculateRedeemableTokens() internal pure override returns (uint256);
```

**Description:**  
Calculates and returns the number of redeemable tokens. For the daily quest, this is always 1.

### _transferRewards

```solidity
function _transferRewards(address _claimer, uint256 _amount) internal override;
```

**Description:**  
Transfers the specified amount of rewards to the claimer.

### _calculateRewards

```solidity
function _calculateRewards(uint256 _redeemableTokens) internal view override returns (uint256);
```

**Description:**  
Calculates and returns the rewards based on the number of redeemable tokens.

### protocolFee

```solidity
function protocolFee() external view returns (uint256);
```

**Description:**  
Calculates and returns the protocol fee based on the number of participants, the reward amount in Wei, and the quest fee.

### withdrawLeftOverRewards

```solidity
function withdrawLeftOverRewards() external onlyFeeReceiverOrOwner nonReentrant() withdrawAllowed;
```

**Description:**  
Allows the contract owner or the fee receiver to withdraw any leftover rewards after the quest has ended.

### isClaimed

```solidity
function isClaimed(address _addressInScope, uint256 _

timestamp) external view returns (bool);
```

**Description:**  
Checks and returns whether a specific address has already claimed its rewards for a particular timestamp.

---
