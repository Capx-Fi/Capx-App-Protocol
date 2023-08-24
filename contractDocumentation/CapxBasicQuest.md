# CapxBasicQuest Contract

The `CapxBasicQuest` contract represents a basic quest inherited from `CapxQuest` in the ecosystem. Participants can claim rewards based on the conditions set in the quest. In the basic quest, this is always 1.

#### Properties:

- `questFee`: A fee associated with the quest, represented as a 16-bit unsigned integer.
- `hasWithdrawn`: A boolean indicating whether the rewards have been withdrawn.
- `feeReceiver`: The address designated to receive the quest fees.
- `claimedUsers`: A mapping that tracks users who have claimed their rewards.

#### Constructor:

```solidity
constructor() {
    _disableInitializers();
}
```

This constructor disables the initializers, ensuring that the contract's initialization functions can only be called once.

#### initialize:

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
Initializes the basic quest with the provided parameters.

**Parameters:**

- `_rewardToken`: The ERC20 token address to be used as a reward.
- `_startTime`: The start time of the quest.
- `_endTime`: The end time of the quest.
- `_maxParticipants`: The maximum number of participants allowed in the quest.
- `_rewardAmountInWei`: The reward amount for each participant.
- `_questId`: A unique identifier for the quest.
- `_questFee`: A fee associated with the quest.
- `_feeReceiver`: The address designated to receive the quest fees.

#### Modifiers:

- `onlyFeeReceiverOrOwner`: Ensures that the caller is either the owner of the contract or the designated fee receiver.

#### totalRewards:

```solidity
function totalRewards() external view returns (uint256);
```

**Description:**  
Returns the total rewards for the quest, calculated as the product of the maximum number of participants and the reward amount.

#### protocolReward:

```solidity
function protocolReward() external view returns (uint256);
```

**Description:**  
Calculates and returns the protocol's reward, which is a percentage (defined by `questFee`) of the total rewards.

#### start:

```solidity
function start() public override;
```

**Description:**  
Starts the quest. Before starting, it checks if the contract has enough balance to cover the total rewards and the protocol reward.

#### claim:

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
Allows participants to claim their rewards for the basic quest.

**Functionality:**

1. Validates that the caller is the `capxQuestForger`.
2. Ensures the claim's timestamp is not in the future.
3. Checks if the maximum participants limit has been reached.
4. Ensures the `_receiver` hasn't already claimed the reward.
5. Validates the quest's status and timing.
6. Verifies the integrity of the `_messageHash` using the provided details.
7. Ensures the signer of the `_messageHash` is the authorized `claimSignerAddress` from the `capxQuestForger`.
8. Marks the `_receiver` as having claimed the reward.
9. Increments the participant count.
10. Calculates and transfers the rewards to the `_receiver`.
11. Updates the total claimed token amount.
12. Emits a `emitClaim` event from the `capxQuestForger` contract, logging the claim details.

#### _calculateRedeemableTokens:

```solidity
function _calculateRedeemableTokens() internal pure override returns (uint256);
```

**Description:**  
Returns the number of redeemable tokens for the quest. In the basic quest, this is always 1.

#### _transferRewards:

```solidity
function _transferRewards(address _claimer, uint256 _amount) internal override;
```

**Description:**  
Transfers the specified reward amount to the claimer.

#### _calculateRewards:

```solidity
function _calculateRewards(uint256 _redeemableTokens) internal view override returns (uint256);
```

**Description:**  
Calculates the reward amount based on the redeemable tokens. In the basic quest, it's a straightforward multiplication.

#### protocolFee:

```solidity
function protocolFee() external view returns (uint256);
```

**Description:**  
Calculates and returns the protocol's fee based on the number of participants and the reward amount.

#### withdrawLeftOverRewards:

```solidity
function withdrawLeftOverRewards() external onlyFeeReceiverOrOwner nonReentrant() withdrawAllowed;
```

**Description:**  
Allows the owner or the fee receiver to withdraw any leftover rewards after the quest has ended.

#### isClaimed:

```solidity
function isClaimed(address _addressInScope, uint256 _timestamp) external view returns (bool);
```

**Description:**  
Checks and returns whether a specific address has claimed the reward for a given timestamp.

---
