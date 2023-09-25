
# TokenPoweredByCapx

`TokenPoweredByCapx` is a smart contract that represents an ERC20 token powered by the Capx ecosystem. This documentation provides an overview of its functionalities and methods.

## Overview

The `TokenPoweredByCapx` contract is an ERC20 token with additional features such as whitelisting, authorization, pausing, and a capped total supply. It also includes hooks for token transfers, which can be used for further customization.

## Modifiers

### checkIsAddressValid

```solidity
modifier checkIsAddressValid(address account);
```

**Description:**  
Ensures that the provided address is valid and not the zero address.

### onlyWhitelisted

```solidity
modifier onlyWhitelisted(address sender, address recipient);
```

**Description:**  
Ensures that either the sender or the recipient is whitelisted or the caller is the contract owner.

### onlyAuthorized

```solidity
modifier onlyAuthorized();
```

**Description:**  
Ensures that the caller is either the contract owner or an authorized address.

## Methods

### initialize

```solidity
function initialize (
    string memory name_, 
    string memory symbol_,
    address owner_,
    address capxQuestForger_,
    uint256 totalCappedSupply_
) external;
```

**Parameters:**
- `name_`: Name of the token.
- `symbol_`: Symbol of the token.
- `owner_`: Address of the contract owner.
- `capxQuestForger_`: Address of the Capx Quest Forger.
- `totalCappedSupply_`: Maximum total supply of the token.

**Description:**  
Initializes the token with the provided parameters. This function can only be called once.

### name, symbol, decimals

```solidity
function name() public view returns (string memory);
function symbol() public view returns (string memory);
function decimals() public view returns (uint8);
```

**Description:**  
These functions return the name, symbol, and decimals of the token, respectively.

### totalSupply, maxTotalSupply

```solidity
function totalSupply() public view returns (uint256);
function maxTotalSupply() public view returns (uint256);
```

**Description:**  
`totalSupply` returns the current total supply of tokens, while `maxTotalSupply` returns the maximum allowed total supply.

### balanceOf

```solidity
function balanceOf(address account) public view returns (uint256);
```

**Parameters:**
- `account`: Address of the account to check the balance for.

**Description:**  
Returns the token balance of the specified account.

### transfer, transferFrom

```solidity
function transfer(address to, uint256 amount) public returns (bool);
function transferFrom(address from, address to, uint256 amount) public returns (bool);
```

**Description:**  
These functions allow for the transfer of tokens. Transfers can only occur between whitelisted addresses or if initiated by the contract owner.

### approve, increaseAllowance, decreaseAllowance

```solidity
function approve(address spender, uint256 amount) public returns (bool);
function increaseAllowance(address spender, uint256 addedValue) public returns (bool);
function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool);
```

**Description:**  
These functions are related to allowances. They allow an owner to approve another address to spend a certain amount of their tokens and to increase or decrease this allowance.

### mint, burn, burnFrom

```solidity
function mint(address account, uint256 amount) external;
function burn(uint256 amount) public;
function burnFrom(address account, uint256 amount) public;
```

**Description:**  
These functions allow for the creation (minting) and destruction (burning) of tokens. Only the contract owner can mint tokens. Any user can burn their own tokens, and they can also burn tokens from another account if they have an allowance.

### pause, unpause

```solidity
function pause() external;
function unpause() external;
```

**Description:**  
These functions allow the contract owner to pause and unpause all token transfers.

### addToWhitelist, removeFromWhitelist

```solidity
function addToWhitelist(address account) external;
function removeFromWhitelist(address account) external;
```

**Description:**  
These functions allow authorized addresses to add or remove addresses from the whitelist.

### addToAuthorized, removeFromAuthorized

```solidity
function addToAuthorized(address account) external;
function removeFromAuthorized(address account) external;
```

**Description:**  
These functions allow the contract owner to add or remove addresses from the list of authorized addresses.

### updateMaxTotalSupply

```solidity
function updateMaxTotalSupply(uint256 __maxTotalSupply) external;
```

**Parameters:**
- `__maxTotalSupply`: The new maximum total supply.

**Description:**  
Allows the contract owner to update the maximum total supply of the token.

## Events

### Whitelisted, Unwhitelisted

```solidity
event Whitelisted(address indexed account);
event Unwhitelisted(address indexed account);
```

**Description:**  
These events are emitted when an address is added to or removed from the whitelist.

### Authorized, UnAuthorized

```solidity
event Authorized(address indexed account);
event UnAuthorized(address indexed account);
```

**Description:**  
These events are emitted when an address is added to or removed from the list of authorized addresses.

---
