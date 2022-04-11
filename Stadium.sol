// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract NextStadium {
    
    address public owner;
    uint public availableSeats;  // Can easily be changed by the owner through the setter function
    uint public totalTickets;

    Ticket[] public sellingPool;
    mapping(address => Ticket) public users;
    address[] public userAddresses;  // Keeps track of addresses inside users (mapping)

    constructor() {
        owner = msg.sender;
        availableSeats = 10;
    }

    struct Ticket {
        address ticketOwner;
        uint position;
        uint retailPriceWei;
        uint currentPriceWei;
        uint eventDate;
    }


    // Owner only functions:

    function createTickets(uint _price, uint _remainingDays) external {
        require(msg.sender == owner, "Only the owner can create new tickets");
        require(availableSeats > 0, "Space available should be greater than 0");
        require(totalTickets == 0, "Tickets alredy created. To create more tickets you have to wait for the current event to finish");
        
        totalTickets = availableSeats; // Does not issue tickets before the end of the event

        for (uint i = 0; i < availableSeats; i ++) {
            Ticket memory ticket = Ticket(
                owner, 
                i, 
                _price, 
                _price,
                block.timestamp + (_remainingDays * 1 days)
            );
            sellingPool.push(ticket);
        }
    }

    function deleteTickets() external {
        require(msg.sender == owner, "Only the owner can delete tickets");
        resetContract();
    }

    function setAvaibleSpace(uint _seats) external {
        require(msg.sender == owner, "Only the owner can modify the available space");
        require(totalTickets == 0, "You cannot change the number of seats available before the current event ends");
        require(_seats > 0, "Space available should be greater than 0");
        
        availableSeats = _seats;
    }


    // User related functions:

    function buyTicket(uint _poolIndex) external payable {
        Ticket memory ticket = sellingPool[_poolIndex];
        require(users[msg.sender].ticketOwner != msg.sender, "You alredy have a ticket");
        require(msg.value == ticket.currentPriceWei, "Ether amount is incorrect");
        if (block.timestamp > ticket.eventDate) {
            resetContract();  // Reset smart contract because tickets have expired
        }
        else {
            (bool sent, bytes memory data) = payable(ticket.ticketOwner).call{value: ticket.currentPriceWei}("");
            require(sent, "Error sending ETH");

            setTicketOwnership(ticket, msg.sender, _poolIndex);
        }
    }

    function sellTicket(uint _newPrice) external {
        require(users[msg.sender].ticketOwner == msg.sender, "You cannot sell a ticket before buying it");
        Ticket memory ticket = users[msg.sender];
        ticket.currentPriceWei = _newPrice;

        sellingPool.push(ticket);
        delete users[msg.sender];
        removeFromAccounts(msg.sender);
    }

    
    // Private functions:

    function setTicketOwnership(Ticket memory _ticket, address _newOwner, uint _index) internal {
        _ticket.ticketOwner = _newOwner;
        users[_newOwner] = _ticket;
        userAddresses.push(_newOwner);
        removeFromPool(_index);
    }

    function removeFromPool(uint _index) internal {
        sellingPool[_index] = sellingPool[sellingPool.length - 1];
        sellingPool.pop();
    }

    function removeFromAccounts(address _addr) internal {
        for (uint i = 0; i < userAddresses.length; i ++) {
            if (userAddresses[i] == _addr) {
                userAddresses[i] = userAddresses[userAddresses.length - 1];
                userAddresses.pop();
                break;
            }
        }
    }

    function resetContract() internal {
        delete sellingPool;
        for (uint i = 0; i < userAddresses.length; i ++) {
            delete users[userAddresses[i]];
        }
        delete userAddresses;
        totalTickets = 0;
    }
}
