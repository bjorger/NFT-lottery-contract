// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts@4.4.2/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.4.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.4.2/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

enum LotteryState {
    WHITELIST_ONLY,
    OPEN,
    DRAWING,
    CLOSED
}

enum EntrantState {
    NEW,
    CURRENTLY_MINTING,
    HAS_TICKET
}

enum DrawingState {
    DRAW_BRACKET,
    DRAW_WINNER
}

struct Entrant {
    address entrantAddress;
    uint256 NFTRarity;
}

contract Lottery is VRFConsumerBase, Ownable, ERC1155 {
    /**
        Work with players mapping to avoid race condition because of chain link oracle
    */
    mapping(bytes32 => address) private entrants_queue;
    mapping(address => EntrantState) private entrants;
    mapping(address => bool) private whitelist;
    IERC20 private _token;
    uint256 public entrantCount;
    uint256 public lotteryPot;
    uint256 MIN_ENTRY_VALUE = 1;
    uint256 MAX_ENTRY_VALUE = 100000;
    bytes32 private keyHash;
    uint256 private fee;
    uint256 private ticketPrice = 0.01 * 10 ** 18;

    LotteryState public lotteryState = LotteryState.OPEN;
    DrawingState public drawingState = DrawingState.DRAW_BRACKET;

    // NFT Rarities
    uint256 constant RARITY_1 = 0;
    uint256 constant RARITY_2 = 1;
    uint256 constant RARITY_3 = 2;
    uint256 constant RARITY_4 = 3;
    uint256 constant RARITY_5 = 4;
    address constant WETH_CONTRACT_ADDRESS = 0x3C68CE8504087f89c640D02d133646d98e64ddd9;

    event RequestedRandomness(bytes32);
    event MintTicket(address, uint256);


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
        _token = IERC20(WETH_CONTRACT_ADDRESS);
    }

    function getContractBalance() public view returns(uint256){
        return address(this).balance;
    }

    function getWETHBalance() public view returns(uint256){
        return _token.balanceOf(address(this));
    }

    /**
     * Lottery Entry
     */
    function enter() public payable {
        if(entrants[msg.sender] == EntrantState.HAS_TICKET){
            revert("Address already has a ticket");
        }
        if(entrants[msg.sender] == EntrantState.CURRENTLY_MINTING){
            revert("Ticket is currently minted");
        }
        if(lotteryState == LotteryState.WHITELIST_ONLY){
            require(whitelist[msg.sender] == true, "Sender not whitelisted");
        }
        require(_token.balanceOf(address(msg.sender)) >= ticketPrice, "Funds are not sufficient");
        _token.transferFrom(msg.sender, address(this), ticketPrice);
        mintEntrantNFT();
    }

    function mintEntrantNFT() private {
        bytes32 id = requestRandomness(keyHash, fee);
        entrants_queue[id] = msg.sender;
        entrants[entrants_queue[id]] = EntrantState.CURRENTLY_MINTING;
        emit RequestedRandomness(id);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        if(lotteryState == LotteryState.OPEN || lotteryState == LotteryState.WHITELIST_ONLY){
            uint256 categoryBracket = (randomness % 100) + 1;
            generateTicket(categoryBracket, requestId);
        }
        else if(lotteryState == LotteryState.DRAWING){
            if(drawingState == DrawingState.DRAW_BRACKET){
                drawingState = DrawingState.DRAW_WINNER;
                uint256 categoryBracket = (randomness % 100) + 1;

                // Draw Bracket
                drawBracket(categoryBracket);
            }
            else if(drawingState == DrawingState.DRAW_WINNER){
                // Draw winner in bracket
            }
        }
    }

    function generateTicket(uint256 categoryBracket, bytes32 requestId) private {
        if (categoryBracket > 0 && categoryBracket <= 40) {
            // Rarity 5
            mintTicket(RARITY_5, requestId);
        }
        else if (categoryBracket > 40 && categoryBracket <= 65) {
            // Rarity 4
            mintTicket(RARITY_4, requestId);
        }
        else if (categoryBracket > 65 && categoryBracket <= 85) {
            // Rarity 3
            mintTicket(RARITY_3, requestId);
        }
        else if (categoryBracket > 85 && categoryBracket <= 95) {
            // Rarity 2
            mintTicket(RARITY_2, requestId);
        }
        else if (categoryBracket > 95 && categoryBracket <= 100) {
            // Rarity 1
            mintTicket(RARITY_1, requestId);
        }
    }

    function drawBracket(uint256 categoryBracket) private {
        if (categoryBracket > 0 && categoryBracket <= 40){
            // Rarity 1
        }
        else if (categoryBracket > 40 && categoryBracket <= 65){
            // Rarity 2
        }
        else if (categoryBracket > 65 && categoryBracket <= 85){
            // Rarity 3
        }
        else if (categoryBracket > 85 && categoryBracket <= 95){
            // Rarity 4
        }
        else if (categoryBracket > 95 && categoryBracket <= 100){
            // Rarity 5
        }
    }

    function mintTicket(uint256 rarity, bytes32 requestId) private {
        _mint(entrants_queue[requestId], rarity, 1, "");
        entrants[entrants_queue[requestId]] = EntrantState.HAS_TICKET;
        entrantCount += 1;
        emit MintTicket(entrants_queue[requestId], rarity);
        delete entrants_queue[requestId];
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