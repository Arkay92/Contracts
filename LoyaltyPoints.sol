// SPDX-License-Identifier: MIT
// Project Name - Cofffee Loyalty Tracker

pragma solidity 0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CoffeeLoyaltyTracker is ReentrancyGuard, Ownable {
    // Set the minimum points required for free coffee
    uint256 pointsRequired = 10;

    // Struct to track customer data
    struct CustomerData {
        uint256 points;
        uint256 freeCoffees;
    }

    // Mapping to track struct data against address
    mapping (address => CustomerData) customers;

    // ===== Check Caller Is User =====
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "[Error] Function cannot be called by a contract");
        _;
    }

    // This function allows the customer to redeem their loyalty points for a reward
    function redeemPoints(uint256 amount) public nonReentrant callerIsUser {
        CustomerData memory customer = customers[msg.sender];
        require(amount <= customer.points, "Insufficient loyalty points.");
        customer.points -= amount;
    }

    // This function allows the customer to earn more loyalty points
    function earnPoints(uint256 amount) public nonReentrant callerIsUser {
        CustomerData memory customer = customers[msg.sender];
        customer.points += amount;
        if(customer.points >= pointsRequired) {
            customer.freeCoffees++;
            customer.points -= pointsRequired;
        }
    }

    // Function to change the points required
    function changePointsRequired(uint256 points) public onlyOwner nonReentrant callerIsUser {
        pointsRequired = points;
    }

    // Funtion to allow users to manage points (send to a friend)
    function sendPoints(uint256 amount, address to) public nonReentrant callerIsUser {
        require(customers[msg.sender].points > 0, "[Error] You have no points to send !");
        customers[msg.sender].points -= amount;
        customers[to].points += amount;
    }

    // Funtion to allow users to manage coffees (send to a friend)
    function sendCoffees(uint256 amount, address to) public nonReentrant callerIsUser {
        require(customers[msg.sender].freeCoffees > 0, "[Error] You have no coffees to send !");
        customers[msg.sender].freeCoffees -= amount;
        customers[to].freeCoffees += amount;
    }
}


