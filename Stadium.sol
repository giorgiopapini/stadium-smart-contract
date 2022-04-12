// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract NextStadium {
    
    address public owner;
    uint public availableSeats;  // Can easily be changed by the owner through the setter function
    bool public saleStarted;
    uint public eventDate;

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
        uint date;
        bytes32 eventName;
    }

    event TicketCreated(
        uint creationTime,
        Ticket ticket
    );

    event TicketBought(
        address seller,
        address buyer,
        Ticket ticket
    );
    

    // Owner only functions:

    function createTickets(uint _price, uint _remainingDays, bytes32 _eventName) external {
        require(msg.sender == owner, "Only the owner can create new tickets");
        require(availableSeats > 0, "Space available should be greater than 0");
        require(!saleStarted, "Tickets alredy created. To create more tickets you have to wait for the current event to finish");
        
        saleStarted = true; // Does not issue tickets before the end of the event
        eventDate = block.timestamp + (_remainingDays * 1 days);

        for (uint i = 0; i < availableSeats; i ++) {
            Ticket memory ticket = Ticket(
                owner, 
                i, 
                _price, 
                _price,
                eventDate,
                _eventName
            );

            sellingPool.push(ticket);
            emit TicketCreated(block.timestamp, ticket);
        }
    }

    function deleteTickets() external {
        require(msg.sender == owner, "Only the owner can delete tickets");
        require(block.timestamp > eventDate, "You can't delete tickets before the event ends");
        resetContract();
    }

    function setAvaibleSpace(uint _seats) external {
        require(msg.sender == owner, "Only the owner can modify the available space");
        require(!saleStarted, "You cannot change the number of seats available before the current event ends");
        require(_seats > 0, "Space available should be greater than 0");
        
        availableSeats = _seats;
    }


    // User related functions:

    function buyTicket(uint _poolIndex) external payable {
        Ticket memory ticket = sellingPool[_poolIndex];
        require(users[msg.sender].ticketOwner != msg.sender, "You alredy have a ticket");
        require(msg.value == ticket.currentPriceWei, "Ether amount is incorrect");
        if (block.timestamp > ticket.date) {
            resetContract();  // Reset smart contract because tickets have expired
        }
        else {
            (bool sent, bytes memory data) = payable(ticket.ticketOwner).call{value: ticket.currentPriceWei}("");
            require(sent, "Error sending ETH");

            address oldOwner = ticket.ticketOwner;

            setTicketOwnership(ticket, msg.sender, _poolIndex);
            emit TicketBought(oldOwner, msg.sender, ticket);
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
        saleStarted = false;
    }
}
