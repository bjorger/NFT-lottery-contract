// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

enum LotteryState {
    WHITELIST_ONLY,
    OPEN,
    DRAWING,
    CLOSED
}

contract Lottery is VRFConsumerBase, Ownable, ERC1155 {
    mapping(address => uint) public entrants;
    mapping(address => bool) whitelist;
    uint256 public entrantCount;
    uint256 public lotteryPot;
    uint256 MIN_ENTRY_VALUE;
    uint256 MAX_ENTRY_VALUE;
    uint256 internal fee;
    uint256 public categoryBracket; 
    LotteryState public lotteryState = LotteryState.WHITELIST_ONLY;
    bytes32 internal keyHash;

    // NFT Rarities
    uint256 constant RARITY_1 = 0;
    uint256 constant RARITY_2 = 1;
    uint256 constant RARITY_3 = 2;
    uint256 constant RARITY_4 = 3;
    uint256 constant RARITY_5 = 4;


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
     * Requests randomness 
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        categoryBracket = (randomness % 100) + 1;

        if (categoryBracket >= 0 && categoryBracket <= 40){
            // Rarity 5
            mintTicket(RARITY_5);
        }
        else if (categoryBracket > 40 && categoryBracket <= 65){
            // Rarity 4
            mintTicket(RARITY_4);
        }
        else if (categoryBracket > 65 && categoryBracket <= 85){
            // Rarity 3
            mintTicket(RARITY_3);
        }
        else if (categoryBracket > 85 && categoryBracket <= 95){
            // Rarity 2
            mintTicket(RARITY_2);
        }
        else if (categoryBracket > 95 && categoryBracket <= 100){
            // Rarity 1
            mintTicket(RARITY_1);
        }
    }

    // function withdrawLink() external {} - Implement a withdraw function to avoid locking your LINK in the contract

    function enter() public payable {
        if(lotteryState == LotteryState.WHITELIST_ONLY){
            require(whitelist[msg.sender] == true, "Sender not whitelisted");
        }
        require(msg.value >= MIN_ENTRY_VALUE, "Funds not sufficient");
        require(msg.value < MAX_ENTRY_VALUE, "Funds exceed maximum entry amount for a single wallet");
        entrantCount += 1;
        entrants[msg.sender] = msg.value;
        lotteryPot += msg.value;
    }

    function addToWhitelist(address addressToWhiteList) public onlyOwner {
        whitelist[addressToWhiteList] = true;
    }

    function removeFromWhitelist(address addressToRemove) public onlyOwner {
        delete(whitelist[addressToRemove]);
    }

    function enableWhitelistMode() public onlyOwner{
        lotteryState = LotteryState.WHITELIST_ONLY;
    }

    function mintTicket(uint rarity) private {
        require(balanceOf(msg.sender, RARITY_1) == 0,"you already have a ticket");
        require(balanceOf(msg.sender, RARITY_2) == 0,"you already have a ticket");
        require(balanceOf(msg.sender, RARITY_3) == 0,"you already have a ticket");
        require(balanceOf(msg.sender, RARITY_4) == 0,"you already have a ticket");
        require(balanceOf(msg.sender, RARITY_5) == 0,"you already have a ticket");

        _mint(msg.sender, rarity, 1, "0x000");
    }
    // function Start lottery
    // function End lottery
}