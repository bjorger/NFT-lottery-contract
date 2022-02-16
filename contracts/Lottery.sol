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
    CURRENT_TICKET_MINTED
}

enum DrawingState {
    DRAW_BRACKET,
    DRAW_WINNER
}

struct Entrant {
    address addr;
    uint256 ticketPrice;
}

contract Lottery is VRFConsumerBase, Ownable, ERC1155 {

    /*
        Private Variables
    */

    bytes32 private keyHash;
    uint256 private fee;
    uint256 private ticketPrice = 0.01 * 10 ** 18;
    uint256 private winnerBracket;
    uint256 private lotteryPot;
    
    /**
        Work with players mapping to avoid race condition because of chain link oracle
    */
    mapping(bytes32 => address) private entrants_queue;
    mapping(address => EntrantState) private entrants;
    mapping(address => bool) private whitelist;
    mapping(uint => mapping(uint => Entrant)) private brackets;
    mapping(uint => uint) private bracketCount;
    IERC20 private _token;
    mapping(uint => uint) private priceMoney;
    uint256 private winnerCount;


    /*
        public variables
    */
    uint256 public entrantCount;
    LotteryState public lotteryState = LotteryState.OPEN;
    DrawingState public drawingState = DrawingState.DRAW_BRACKET;

    // NFT Rarities
    uint256 constant RARITY_1 = 1;
    uint256 constant RARITY_2 = 2;
    uint256 constant RARITY_3 = 3;
    uint256 constant RARITY_4 = 4;
    uint256 constant RARITY_5 = 5;

    // Addresses
    address constant WETH_CONTRACT_ADDRESS = 0x3C68CE8504087f89c640D02d133646d98e64ddd9;
    address constant CHAINLINK_VRF_COORDINATOR = 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255;
    address constant CHAINLINK_TOKEN = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;

    event RequestedRandomness(bytes32);
    event MintTicket(address, uint256);
    event PayWinner(address, uint256);


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
            CHAINLINK_VRF_COORDINATOR, // VRF Coordinator
            CHAINLINK_TOKEN  // LINK Token
        )
        ERC1155("https://gateway.pinata.cloud/ipfs/QmTN32qBKYqnyvatqfnU8ra6cYUGNxpYziSddCatEmopLR/metadata/api/item/{id}.json") 
    {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
        _token = IERC20(WETH_CONTRACT_ADDRESS);
    }

    function getContractBalance() public view onlyOwner returns(uint256){
        return address(this).balance;
    }

    function getWETHBalance() public view onlyOwner returns(uint256){
        return _token.balanceOf(address(this));
    }

    function getLotteryPot() public view returns (uint256){
        return lotteryPot;
    }

    function getTicketPrice() public view returns (uint256){
        return ticketPrice;
    }

    function getEntrantStatus(address entrant) public view returns (EntrantState){
        return entrants[entrant];
    }

    function getLotteryState() public view returns (LotteryState) {
        return lotteryState;
    }

    function withDraw() public {
        // Withdraw money to hardcoded wallet -> eventhough when contract is hacked, non of the funds can be touched
    }

    function calculateAccumulatedTicketsOfAddress(address player) public view returns (uint256) {
        return balanceOf(player, RARITY_1) + balanceOf(player, RARITY_2) + balanceOf(player, RARITY_3) + balanceOf(player, RARITY_4) + balanceOf(player, RARITY_5);
    }

    /**
     * Lottery Entry
     */
    function enter() public payable {
        require(calculateAccumulatedTicketsOfAddress(msg.sender) < 3, "Address already possess 3 tickets");
        require(lotteryState == LotteryState.OPEN || lotteryState == LotteryState.WHITELIST_ONLY, "Lottery is not open");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - Cannot start VRF");
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

    function generateTestUsers(address _addr) public {
        for(uint i = 0; i < 10; i++){
            brackets[RARITY_1][bracketCount[RARITY_1]] = Entrant(_addr, ticketPrice);
            bracketCount[RARITY_1] += 1;
            entrantCount += 1;
        }
        for(uint i = 0; i < 10; i++){
            brackets[RARITY_2][bracketCount[RARITY_2]] = Entrant(_addr, ticketPrice);
            bracketCount[RARITY_2] += 1;
            entrantCount += 1;
        }
        for(uint i = 0; i < 10; i++){
            brackets[RARITY_3][bracketCount[RARITY_3]] = Entrant(_addr, ticketPrice);
            bracketCount[RARITY_3] += 1;
            entrantCount += 1;
        }
        for(uint i = 0; i < 10; i++){
            brackets[RARITY_4][bracketCount[RARITY_4]] = Entrant(_addr, ticketPrice);
            bracketCount[RARITY_4] += 1;
            entrantCount += 1;
        }
        for(uint i = 0; i < 10; i++){
            brackets[RARITY_5][bracketCount[RARITY_5]] = Entrant(_addr, ticketPrice);
            bracketCount[RARITY_5] += 1;
            entrantCount += 1;
        }

        lotteryPot = 0.5 * 10 ** 18;
    }

    function testFunctionDELETETHIS(address _addr, uint256 rarity) public {
        _mint(_addr, rarity, 1, "");
        brackets[rarity][bracketCount[rarity]] = Entrant(_addr, ticketPrice);
        bracketCount[rarity] += 1;
        entrantCount += 1;
        lotteryPot += (ticketPrice * 8) / 10;

        emit MintTicket(_addr, rarity);
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
                winnerBracket = drawBracket(categoryBracket);
                requestRandomness(keyHash, fee);
            }
            else if(drawingState == DrawingState.DRAW_WINNER && winnerBracket != 0 && bracketCount[winnerBracket] != 0){
                // Draw winner in bracket
                Entrant memory winner = brackets[winnerBracket][randomness % bracketCount[winnerBracket]];
                // remove winner from lottery so he can't win again
                delete brackets[winnerBracket][randomness % bracketCount[winnerBracket]];
                bracketCount[winnerBracket] -= 1;

                payWinner(winner.addr, priceMoney[winnerCount]);

                drawingState = DrawingState.DRAW_BRACKET;
                winnerCount += 1;

                if(winnerCount < 3){
                    requestRandomness(keyHash, fee);
                }
                else{
                    lotteryState = LotteryState.CLOSED;
                }
            }
            // start new drawing to find new bracket
            else {
                requestRandomness(keyHash, fee);
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

    function drawBracket(uint256 categoryBracket) private pure returns (uint256 _rarity) {
        if (categoryBracket > 0 && categoryBracket <= 40){
            return RARITY_1;
        }
        else if (categoryBracket > 40 && categoryBracket <= 65){
            return RARITY_2;
        }
        else if (categoryBracket > 65 && categoryBracket <= 85){
            return RARITY_3;
        }
        else if (categoryBracket > 85 && categoryBracket <= 95){
            return RARITY_4;
        }
        else if (categoryBracket > 95 && categoryBracket <= 100){
            return RARITY_5;
        }
        else{
            // return non existing rarity;
            return 0;
        }
    }

    function mintTicket(uint256 rarity, bytes32 requestId) private {
        address player = entrants_queue[requestId];
        _mint(player, rarity, 1, "");
        brackets[rarity][bracketCount[rarity]] = Entrant(player, ticketPrice);
        bracketCount[rarity] += 1;
        entrantCount += 1;
        lotteryPot += (ticketPrice * 8) / 10;

        if(entrantCount == 1001){
            ticketPrice = 0.02 * 10 ** 18;
        }
        else if(entrantCount == 2001){
            ticketPrice = 0.03 * 10 ** 18;
        }
        else if(entrantCount == 3001){
            ticketPrice = 0.04 * 10 ** 18;
        }
        else if(entrantCount == 5001){
            ticketPrice = 0.05 * 10 ** 18;
        }
        else if(entrantCount == 10001){
            ticketPrice = 0.06 * 10 ** 18;
        }
        else if(entrantCount == 20001){
            ticketPrice = 0.07 * 10 ** 18;
        }
        else if(entrantCount >= 30001) {
            ticketPrice = 0.08 * 10 ** 18;
        }
        entrants[player] = EntrantState.CURRENT_TICKET_MINTED;
        emit MintTicket(player, rarity);
        delete entrants_queue[requestId];
    }

    function payWinner(address winner, uint256 amount) private onlyOwner {
        require(
            balanceOf(winner, RARITY_1) == 1 || 
            balanceOf(winner, RARITY_2) == 1 ||
            balanceOf(winner, RARITY_3) == 1 ||
            balanceOf(winner, RARITY_4) == 1 ||
            balanceOf(winner, RARITY_5) == 1, "Address does not own valid ticket");
        _token.transfer(winner, amount);
        emit PayWinner(winner, amount);
    }

    function startDrawing() public payable onlyOwner {
        // Times 6, because the oracle will be called 6 times to find the 3 winners
        // call of requestRandomness in startDrawing() to get Winner Bracket of First Winner => Fee Number one
        // call of requestRandomness in fulfillRandomness to get first Winner => Fee Number two
        // call of requestRandomness in fulfillRandomness to get Winner Bracket of Second Winner => Fee Number three
        // call of requestRandomness in fulfillRandomness to get second Winner => Fee Number four
        // call of requestRandomness in fulfillRandomness to get Winner Bracket of Third Winner => Fee Number five
        // call of requestRandomness in fulfillRandomness to get Third Winner => Fee Number six
        require(LINK.balanceOf(address(this)) >= fee * 6, "Not enough LINK - Cannot start VRF");

        if (entrantCount >= 1000){
            lotteryState = LotteryState.DRAWING;
            priceMoney[0] = lotteryPot * 7 / 10;
            priceMoney[1] = lotteryPot * 2 / 10;
            priceMoney[2] = lotteryPot * 1 / 10;
            requestRandomness(keyHash, fee);
        }
        else {
            // TODO: test payback function
            paybackPlayers();
        }

    }

    function paybackPlayers() private onlyOwner {
        // Brackets 1 2 3 4 5
        for(uint i = 1; i <= 5; i++){
            for(uint j = 0; j < bracketCount[i]; j++){
                _token.transfer(brackets[i][j].addr, brackets[i][j].ticketPrice * 8 / 10);
                lotteryPot -= brackets[i][j].ticketPrice * 8 / 10;
                delete brackets[i][j];
                bracket
            }
        }
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

    function disableWhitelistMode() public onlyOwner{
        lotteryState = LotteryState.OPEN;
    }
}