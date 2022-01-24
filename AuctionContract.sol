// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 < 0.9.0;


contract Auction {
    address payable public owner;
    uint public genesisBlock;
    uint public lastBlock;
    string public ipfsHash;
    
    enum State {Started, Running, Ended, Cancelled}     // State sequence: {0,1,2,3}
    State public auctionState;

    uint public highestBindingBid;
    address payable public highestBidder;

    mapping(address => uint) public bids;
    uint bidIncrement;

    // owner can finalise auction and obtain highestBindingBid only once
    bool public ownerFinalised = false;

    constructor() {
        owner = payable(msg.sender);
        auctionState = State.Running;
        
        genesisBlock = block.number;    // "block.number" is global variable
        lastBlock = genesisBlock + 3;   // +3 used on this case, however, 604800(total # of seconds) divided by 15sec(block time) = 40320 blocks generated
        
        ipfsHash = "";
        bidIncrement = 1000000000000000000; //1 eth in wei
        }

        // declaration of function modifiers
        modifier notOwner() {
            require(msg.sender != owner);
            _;
        }

        modifier afterGenesis() {
            require(block.number >= genesisBlock);
            _;
        }

        modifier beforeLast() {
            require(block.number <= lastBlock);
            _;
        }

        modifier onlyOwner() {
            require(msg.sender == owner);
            _;
        }

        // helper function:
        function min(uint a, uint b) pure internal returns(uint) {  //neither alters nor reads from blockchain, hence 'pure'
            if(a <= b) {
                return a;
            }else {
                return b;
            }
        }   

        function cancelAuction() public onlyOwner {
            auctionState = State.Cancelled;
        }

        function placeBid() public payable notOwner afterGenesis beforeLast returns(bool) {   // linking modifiers to function
            require(auctionState == State.Running);
            //require(msg.value >= 100);  // >=100gwei
        

        uint currentBid = bids[msg.sender] + msg.value;
        require(currentBid > highestBindingBid);
        
        bids[msg.sender] = currentBid;

        if(currentBid <= bids[highestBidder]) {
            highestBindingBid = min(currentBid + bidIncrement, bids[highestBidder]);
        }else {
            highestBindingBid = min(currentBid, bids[highestBidder] + bidIncrement);
            highestBidder = payable(msg.sender);
        }
        return true;
    }

        function finaliseAuction() public {
            require(auctionState == State.Cancelled || block.number > lastBlock);
            require(msg.sender == owner || bids[msg.sender] > 0);

            address payable recipient;
            uint value;

            if(auctionState == State.Cancelled) {   // in the scenario that auction gets cancelled
                recipient = payable(msg.sender);
                value = bids[msg.sender];
            } else { // auction ended (not cancelled)
                if(msg.sender == owner && ownerFinalised == false) {
                    recipient = owner;
                    value = highestBindingBid; 

                // owner can finalise auction and obtain highestBindingBid only once
               ownerFinalised = true; 
            } else {    // another user (not the owner) finalises auction
               if (msg.sender == highestBidder){
                   recipient = highestBidder;
                   value = bids[highestBidder] - highestBindingBid;
               } else {   // this is neither owner nor highest bidder (just a regular bidder)
                   recipient = payable(msg.sender);
                   value = bids[msg.sender];
               }
           }
       }

            // resetting the bids of the recipient to zero
            bids[recipient] = 0;    // prevents security vulnerability

            // value to be sent to recipient
            recipient.transfer(value);
        }
}