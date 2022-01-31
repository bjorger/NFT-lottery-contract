// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract Lottery is VRFConsumerBase, Ownable {
    bytes32 internal keyHash;
    uint256 internal fee;
    
    uint256 public categoryBracket; 

    mapping(address => uint) public entrants;
    mapping(uint => address) whitelist;
    uint256 whitelistCount;
    uint256 public entrantCount;
    uint256 public lotteryPot;
    uint256 MIN_ENTRY_VALUE;
    uint256 MAX_ENTRY_VALUE;

    enum NFTCategory {
        RARITY_1,
        RARITY_2,
        RARITY_3,
        RARITY_4,
        RARITY_5
    }

    enum LotteryState {
        OPEN,
        DRAWING,
        CLOSED
    }

    enum WhitelistPhase { 
        IS_IN_WHITELIST_PHASE,
        IS_IN_NORMAL_PHASE
    }

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
        }
        else if (categoryBracket > 40 && categoryBracket <= 65){
            // Rarity 4
        }
        else if (categoryBracket > 65 && categoryBracket <= 85){
            // Rarity 3
        }
        else if (categoryBracket > 85 && categoryBracket <= 95){
            // Rarity 2
        }
        else if (categoryBracket > 95 && categoryBracket <= 100){
            // Rarity 1
        }
    }

    // function withdrawLink() external {} - Implement a withdraw function to avoid locking your LINK in the contract

    function enter() public payable {
        require(msg.value >= MIN_ENTRY_VALUE, "Funds not sufficient");
        require(msg.value < MAX_ENTRY_VALUE, "Funds exceed maximum entry amount for a single wallet");
        entrantCount += 1;
        entrants[msg.sender] = msg.value;
        lotteryPot += msg.value;
    }

    function addToWhitelist(address addressToWhiteList) public onlyOwner {
        whitelist[whitelistCount] = addressToWhiteList;
        whitelistCount += 1; 
    }

    function getWhitelist() public view returns (address[] memory){
        address[] memory _whitelist;

        for(uint i = 0; i < whitelistCount; i++){
            _whitelist[i] = whitelist[i];
        }

        return _whitelist;
    }
}