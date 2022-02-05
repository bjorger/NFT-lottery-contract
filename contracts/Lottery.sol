// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts@4.4.2/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.4.2/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

enum LotteryState {
    WHITELIST_ONLY,
    OPEN,
    DRAWING,
    CLOSED
}

struct Entrant {
    address entrantAddress;
    uint256 NFTRarity;
}

contract Lottery is VRFConsumerBase, Ownable, ERC1155 {
    // moralis 
    mapping(bytes32 => address payable) players;
    mapping(address => bool) whitelist;
    uint256 public entrantCount;
    uint256 public lotteryPot;
    uint256 MIN_ENTRY_VALUE = 1;
    uint256 MAX_ENTRY_VALUE = 100000;
    uint256 public categoryBracket; 
    LotteryState public lotteryState = LotteryState.OPEN;
    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 internal currentUserValue;

    // NFT Rarities
    uint256 constant RARITY_1 = 0;
    uint256 constant RARITY_2 = 1;
    uint256 constant RARITY_3 = 2;
    uint256 constant RARITY_4 = 3;
    uint256 constant RARITY_5 = 4;

    event RequestedRandomness(bytes32 id);
    event CategoryBracket(uint256 bracket);
    event MintTicket(address player, uint256 rarity);

    /**
     * Constructor inherits VRFConsumerBase
     * 
     * Network: Polygon
     * Chainlink VRF Coordinator address: 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255
     * LINK token address:                0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     * Key Hash:                          0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4
     */
    constructor() 
        VRFConsumerBase(
            0x8C7382F9D8f56b33781fE506E897a4F1e2d17255, // VRF Coordinator
            0x326C977E6efc84E512bB9C30f76E30c160eD06FB  // LINK Token
        )
        ERC1155("https://gateway.pinata.cloud/ipfs/QmTN32qBKYqnyvatqfnU8ra6cYUGNxpYziSddCatEmopLR/metadata/api/item/{id}.json") 
    {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
    }

    /**
     * Lottery Entry
     */
    function enter() public payable {
        if(lotteryState == LotteryState.WHITELIST_ONLY){
            require(whitelist[msg.sender] == true, "Sender not whitelisted");
        }
        require(msg.value >= MIN_ENTRY_VALUE, "Funds not sufficient");
        mintEntrantNFT();
    }

    function mintEntrantNFT() private {
        bytes32 id = requestRandomness(keyHash, fee);
        players[id] = payable(msg.sender);
        emit RequestedRandomness(id);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        categoryBracket = (randomness % 100) + 1;
        emit CategoryBracket(categoryBracket);
        if (categoryBracket > 0 && categoryBracket <= 40){
            // Rarity 5
            mintTicket(RARITY_5, requestId);
        }
        else if (categoryBracket > 40 && categoryBracket <= 65){
            // Rarity 4
            mintTicket(RARITY_4, requestId);
        }
        else if (categoryBracket > 65 && categoryBracket <= 85){
            // Rarity 3
            mintTicket(RARITY_3, requestId);
        }
        else if (categoryBracket > 85 && categoryBracket <= 95){
            // Rarity 2
            mintTicket(RARITY_2, requestId);
        }
        else if (categoryBracket > 95 && categoryBracket <= 100){
            // Rarity 1
            mintTicket(RARITY_1, requestId);
        }
    }

    function mintTicket(uint256 rarity, bytes32 requestId) private {
        require(balanceOf(msg.sender, RARITY_1) == 0,"you already have a ticket");
        require(balanceOf(msg.sender, RARITY_2) == 0,"you already have a ticket");
        require(balanceOf(msg.sender, RARITY_3) == 0,"you already have a ticket");
        require(balanceOf(msg.sender, RARITY_4) == 0,"you already have a ticket");
        require(balanceOf(msg.sender, RARITY_5) == 0,"you already have a ticket");

        _mint(players[requestId], rarity, 1, "");
        emit MintTicket(players[requestId], rarity);
        entrantCount += 1;
        // Pot not working Fix tomorrow
        lotteryPot += currentUserValue;
    }

    function drawWinner(uint256 rarity) public onlyOwner payable {
        require(balanceOf(msg.sender, rarity) == 1, "Address does not own valid ticket");
    }

    /**
     * Whitelist 
     */
    function addToWhitelist(address addressToWhiteList) public onlyOwner {
        whitelist[addressToWhiteList] = true;
    }

    function removeFromWhitelist(address addressToRemove) public onlyOwner {
        delete(whitelist[addressToRemove]);
    }

    function enableWhitelistMode() public onlyOwner{
        lotteryState = LotteryState.WHITELIST_ONLY;
    }

}