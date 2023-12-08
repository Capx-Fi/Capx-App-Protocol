// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CapxGameResource is ERC1155, ReentrancyGuard, Ownable {
    // Define constants for resource types
    uint256 public constant FIRE = 1;
    uint256 public constant WATER = 2;
    uint256 public constant AIR = 3;
    uint256 public constant EARTH = 4;
    uint256 public constant LOOTBOX = 5;
    uint256 public constant MAX_LOOTBOXES = 1000000; // Cap of lootboxes
    uint256 public constant MAX_RESOURCES_PER_MINT = 12; // Max amount of resources that can be minted together.

    // To keep track of user's minting.
    mapping(address => uint256) public lastMinedTimestamp;
    uint256 constant MINE_INTERVAL = 6 * 60 * 60; // 6 hours in seconds

    uint256 public lootBoxMinted = 0;

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
            "CapxID: Caller NOT Authorized."
        );
        _;
    }

    constructor(address _authorizedMinter, string memory _baseURI)
        ERC1155(string(abi.encodePacked(_baseURI, "{id}.json")))
    {
        require(
            _authorizedMinter != address(0),
            "CapxID: ZeroAddress NOT Allowed"
        );
        authorizedMinter = _authorizedMinter;
        baseURI = _baseURI;
    }

    function updateBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    // Called by authorizedMinter
    function mintResources(
        address player,
        uint256[] memory resources,
        uint256[] memory amounts,
        uint256 mineTimeStamp
    ) external onlyAuthorized {
        require(
            resources.length == 4 && amounts.length == 4,
            "Invalid length of resources or amount provided"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < 4; i++) {
            require(
                resources[i] >= FIRE && resources[i] <= EARTH,
                "Invalid resource ID"
            );
            require(
                amounts[i] > 0,
                " Mint amount for tokenID should be greater than 0"
            );
            totalAmount += amounts[i];
        }

        require(
            totalAmount <= MAX_RESOURCES_PER_MINT,
            "Exceeds max resources per mint"
        );

        require(
            mineTimeStamp >= lastMinedTimestamp[player] + MINE_INTERVAL,
            "Can only mint after mine interval"
        );

        require(
            mineTimeStamp < block.timestamp,
            "Mine Timestamp cannot be in the future"
        );

        lastMinedTimestamp[player] = mineTimeStamp;

        _mintBatch(player, resources, amounts, "");

        emit CapxResourcesMinted(player, resources, amounts, mineTimeStamp);
    }

    function craftLootbox(address player) external onlyAuthorized {
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
            "Not enough resources to craft a lootbox"
        );

        require(lootBoxMinted + 1 <= MAX_LOOTBOXES, "Exceeds max lootboxes");

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
    ) external onlyAuthorized{
        require(
            resources.length == 4 && amounts.length == 4,
            "Invalid length of resources or amount provided"
        );

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < 4; i++) {
            require(
                resources[i] >= FIRE && resources[i] <= EARTH,
                "Invalid resource ID"
            );
            totalAmount += amounts[i];
        }

        require(
            totalAmount <= MAX_RESOURCES_PER_MINT,
            "Exceeds max resources per mint"
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

    function burnLootbox(address player) external returns (uint256) {
        require(
            balanceOf(player, LOOTBOX) > 0,
            "User does not have lootboxes to redeem."
        );
        uint256 lootboxIndexPointer = userRedeemedLootBox[player];
        uint256 redeemedLootboxId = lootBoxIDs[player][lootboxIndexPointer];
        userRedeemedLootBox[_msgSender()] =
            userRedeemedLootBox[_msgSender()] +
            1;
        _burn(player, LOOTBOX, 1);
        return redeemedLootboxId;
    }
}
