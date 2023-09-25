# CapxTokenForger

The `CapxTokenForger` contract is designed to forge or create new tokens within the Capx ecosystem. It provides functionalities to create new tokens, manage token parameters, and handle token-related operations.

## Overview

The contract integrates with various OpenZeppelin upgradeable contracts for enhanced security and modularity. It also interacts with the `TokenPoweredByCapx` abstract contract to provide a comprehensive token management system.

## Modifiers

### initializer

Ensures that certain functions can only be called during the contract's initialization phase.

### checkIsAddressValid

```solidity
modifier checkIsAddressValid(address _address);
```

**Description:**  
Ensures that the provided address is valid and not a zero address.

## Methods

### initialize

```solidity
function initialize(
    address _tokenPoweredByCapx
) external checkIsAddressValid(_tokenPoweredByCapx) initializer;
```

**Description:**  
Initializes the contract with the address of the `TokenPoweredByCapx` contract.

### pause, unPause

```solidity
function pause() public onlyOwner whenNotPaused;
function unPause() public onlyOwner whenPaused;
```

**Description:**  
Allows the contract owner to pause or unpause the contract, halting or resuming its operations.

### updateTokenPoweredByCapx

```solidity
function updateTokenPoweredByCapx(
    address _tokenPoweredByCapx
) external onlyOwner checkIsAddressValid(_tokenPoweredByCapx) whenNotPaused;
```

**Description:**  
Allows the contract owner to update the address of the `TokenPoweredByCapx` contract.

### updateCapxQuestForger

```solidity
function updateCapxQuestForger(
    address _capxQuestForger
) external onlyOwner checkIsAddressValid(_capxQuestForger) whenNotPaused;
```

**Description:**  
Allows the contract owner to update the address of the `CapxQuestForger` contract.

### createTokenPoweredByCapx

```solidity
function createTokenPoweredByCapx(
    string memory name,
    string memory symbol,
    address _owner,
    uint256 totalCappedSupplyInWei
) external onlyOwner checkIsAddressValid(_owner) nonReentrant() whenNotPaused virtual returns(address _tokenPoweredByCapx);
```

**Description:**  
Creates a new token with the specified parameters and returns the address of the newly created token.

### isTokenPoweredByCapx

```solidity
function isTokenPoweredByCapx(address _tokenPoweredByCapx) external view returns(bool);
```

**Description:**  
Checks if a given token address is powered by Capx.

## Events

### NewTokenPoweredByCapx

```solidity
event NewTokenPoweredByCapx (
    address indexed tokenPoweredByCapx,
    address indexed owner,
    string name,
    string symbol,
    uint256 maxTotalSupply
);
```

**Description:**  
Emitted when a new token is created in the system.

---