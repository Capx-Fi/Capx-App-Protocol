// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract CapxGameResource is ERC1155, ReentrancyGuard, Ownable, Pausable {
    // Define constants for resource types
    uint256 public constant FIRE = 1;
    uint256 public constant WATER = 2;
    uint256 public constant AIR = 3;
    uint256 public constant EARTH = 4;
    uint256 public constant LOOTBOX = 5;

    // To keep track of user's minting.
    mapping(address => uint256) public lastMinedTimestamp;
    uint256 mineInterval = 6 * 60 * 60; // 6 hours in seconds

    uint256 public lootBoxMinted = 0;
    uint256 public maxLootboxes = 1000000;
    uint256 public maxResourcesPerMint = 12; // Max amount of resources that can be minted together.
    uint256 public maxRedeemResourcesPerMint = 2; // Max amount of resources that can be redeemed
    uint256 public maxLootboxesTransferable = 3; // Max amount of lootboxes that user can transfer.

    mapping(address => uint256[]) public lootBoxIDs;
    mapping(address => uint256) public userRedeemedLootBox;

    address public authorizedMinter;

    string public baseURI;

    // Event for emitting mintResources
    event CapxResourcesMinted(
        address player,
        uint256[] resources,
        uint256[] amounts,
        uint256 minedTimestamp
    );

    // Event for emitting craftLootbox
    event CapxLootboxForged(address player, uint256 lootboxID);

    modifier onlyAuthorized() {
        require(
            owner() == _msgSender() || _msgSender() == authorizedMinter,
            "CapxResource: Caller NOT Authorized."
        );
        _;
    }

    constructor(address _authorizedMinter, string memory _baseURI)
        ERC1155(string(abi.encodePacked(_baseURI, "{id}.json")))
    {
        require(
            _authorizedMinter != address(0),
            "CapxResource: ZeroAddress NOT Allowed"
        );
        authorizedMinter = _authorizedMinter;
        baseURI = _baseURI;
    }

    function updateBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external virtual whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external virtual whenPaused onlyOwner {
        _unpause();
    }

    function mintResources(
        address player,
        uint256[] memory resources,
        uint256[] memory amounts,
        uint256 mineTimeStamp
    ) external onlyAuthorized whenNotPaused nonReentrant {
        require(
            resources.length == 4 && amounts.length == 4,
            "CapxResource: Invalid length of resources or amount provided"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < 4; i++) {
            require(
                resources[i] >= FIRE && resources[i] <= EARTH,
                "CapxResource: Invalid resource ID"
            );
            require(
                amounts[i] > 0,
                "CapxResource: Mint amount for tokenID should be greater than 0"
            );
            totalAmount += amounts[i];
        }

        require(
            totalAmount <= maxResourcesPerMint,
            "CapxResource: Exceeds max resources per mint"
        );

        require(
            mineTimeStamp >= lastMinedTimestamp[player] + mineInterval,
            "CapxResource: Can only mint after mine interval"
        );

        require(
            mineTimeStamp < block.timestamp,
            "CapxResource: Mine Timestamp cannot be in the future"
        );

        lastMinedTimestamp[player] = mineTimeStamp;

        _mintBatch(player, resources, amounts, "");

        emit CapxResourcesMinted(player, resources, amounts, mineTimeStamp);
    }

    function craftLootbox(address player)
        external
        onlyAuthorized
        whenNotPaused
        nonReentrant
    {
        uint256[] memory resources = new uint256[](4);
        resources[0] = FIRE;
        resources[1] = WATER;
        resources[2] = AIR;
        resources[3] = EARTH;

        address[] memory playerArray = new address[](4);
        playerArray[0] = player;
        playerArray[1] = player;
        playerArray[2] = player;
        playerArray[3] = player;

        uint256[] memory balances = balanceOfBatch(playerArray, resources);

        require(
            balances[0] > 0 &&
                balances[1] > 0 &&
                balances[2] > 0 &&
                balances[3] > 0,
            "CapxResource: Not enough resources to craft a lootbox"
        );

        require(
            lootBoxMinted + 1 <= maxLootboxes,
            "CapxResource: Exceeds max lootboxes"
        );

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;
        amounts[3] = 1;

        _burnBatch(player, resources, amounts);

        lootBoxMinted += 1;

        lootBoxIDs[player].push(lootBoxMinted);

        _mint(player, LOOTBOX, 1, "");

        emit CapxLootboxForged(player, lootBoxMinted);
    }

    function redeemResources(
        address player,
        uint256[] memory resources,
        uint256[] memory amounts
    ) external onlyAuthorized whenNotPaused nonReentrant {
        require(
            resources.length == 4 && amounts.length == 4,
            "CapxResource: Invalid length of resources or amount provided"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < 4; i++) {
            require(
                resources[i] >= FIRE && resources[i] <= EARTH,
                "CapxResource: Invalid resource ID"
            );
            totalAmount += amounts[i];
        }

        require(
            totalAmount <= maxRedeemResourcesPerMint,
            "CapxResource: Exceeds max resources per mint"
        );

        _mintBatch(player, resources, amounts, "");
    }

    function uri(uint256 _tokenid)
        public
        view
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(baseURI, Strings.toString(_tokenid), ".json")
            );
    }

    function burnLootbox(address player)
        external
        onlyAuthorized
        whenNotPaused
        nonReentrant
        returns (uint256)
    {
        require(
            balanceOf(player, LOOTBOX) > 0,
            "CapxResource: User does not have lootboxes to redeem."
        );
        uint256 lootboxIndexPointer = userRedeemedLootBox[player];
        uint256 redeemedLootboxId = lootBoxIDs[player][lootboxIndexPointer];
        userRedeemedLootBox[_msgSender()] += 1;
        _burn(player, LOOTBOX, 1);
        return redeemedLootboxId;
    }

    function updateMaxLootbox(uint256 _maxLootboxes) external onlyOwner {
        require(
            _maxLootboxes > 0,
            "CapxResource: max lootboxes has to be greater than 0"
        );
        maxLootboxes = _maxLootboxes;
    }

    function updateMaxResourcesPerMint(uint256 _maxResourcesPerMint)
        external
        onlyOwner
    {
        require(
            _maxResourcesPerMint > 0,
            "CapxResource: max resources per mint has to be greater than 0"
        );
        maxResourcesPerMint = _maxResourcesPerMint;
    }

    function updateMaxRedeemResourcesPerMint(uint256 _maxRedeemResourcesPerMint)
        external
        onlyOwner
    {
        require(
            _maxRedeemResourcesPerMint > 0,
            "CapxResource: max redeem resources per mint has to be greater than 0"
        );
        maxRedeemResourcesPerMint = _maxRedeemResourcesPerMint;
    }

    function updateMaxLootboxesTransferable(uint256 _maxLootboxesTransferable)
        external
        onlyOwner
    {
        require(
            _maxLootboxesTransferable > 0,
            "CapxResource: max lootboxes transferable has to be greater than 0"
        );
        maxLootboxesTransferable = _maxLootboxesTransferable;
    }

    function updateMineInterval(uint256 _mineInterval) external onlyOwner {
        mineInterval = _mineInterval;
    }

    function _performLootboxTransfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        for (uint256 i = 0; i < amount; i++) {
            uint256 redeemedLootboxId = lootBoxIDs[from][
                userRedeemedLootBox[from] + i
            ];
            lootBoxIDs[to].push(redeemedLootboxId);
        }
        userRedeemedLootBox[from] += amount;
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory resources,
        uint256[] memory amounts,
        bytes memory data
    ) public override whenNotPaused {
        require(
            resources.length == amounts.length,
            "CapxResource: Resources and amounts must have the same length"
        );
        bool isLootBoxTransfer;
        uint256 lootBoxIndexPointer;
        for (
            uint256 resourceId = 0;
            resourceId < resources.length;
            resourceId++
        ) {
            require(
                resources[resourceId] >= FIRE &&
                    resources[resourceId] <= LOOTBOX,
                "CapxResource: Invalid resource ID"
            );
            if (resources[resourceId] == LOOTBOX) {
                lootBoxIndexPointer = resourceId;
                isLootBoxTransfer = true;
                require(
                    amounts[lootBoxIndexPointer] > 0 &&
                        amounts[lootBoxIndexPointer] <=
                        maxLootboxesTransferable,
                    "CapxResource: lootbox amount has exceeded the max tranferable amount."
                );
            }
        }

        if (isLootBoxTransfer) {
            _performLootboxTransfer(from, to, amounts[lootBoxIndexPointer]);
        }

        super.safeBatchTransferFrom(from, to, resources, amounts, data);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 resource,
        uint256 amount,
        bytes memory data
    ) public override whenNotPaused {
        require(
            resource >= FIRE && resource <= LOOTBOX,
            "CapxResource: Invalid resource ID"
        );

        if (resource == LOOTBOX) {
            require(
                amount > 0 && amount <= maxLootboxesTransferable,
                "CapxResource: lootbox amount has exceeded the max tranferable amount."
            );
            
            _performLootboxTransfer(from, to, amount);
        }


        super.safeTransferFrom(from, to, resource, amount, data);
    }

    function updateAuthorizedMinter(address _authorizedMinter)
        external
        onlyOwner
    {
        require(
            _authorizedMinter != address(0),
            "CapxResource: ZeroAddress NOT Allowed"
        );
        authorizedMinter = _authorizedMinter;
    }
}
