// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function WETH() external pure returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract SimpleHedgeFund is ReentrancyGuard, Pausable {
    address public owner;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public claimedProfits;
    uint256 public totalInvested;
    uint256 public totalFunds;
    uint256 public totalProfits;

    address private immutable UNISWAP_V2_ROUTER;
    address public investmentToken;
    address[] public investors;
    mapping(address => bool) public isInvestor;

    event InvestmentReceived(address investor, uint256 amount);
    event WithdrawalMade(address investor, uint256 amount);
    event InvestmentMade(uint256 amountOutMin, uint256 deadline);
    event ProfitsAdded(uint256 amount);
    event ProfitClaimed(address investor, uint256 amount);
    event EmergencyWithdrawal(address investor, uint256 amount);
    event TokensManaged(address token, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    constructor(address _investmentToken) {
        owner = msg.sender;
        investmentToken = _investmentToken;
    }

    function invest() public nonReentrant payable {
        require(msg.value > 0, "Investment must be greater than 0");
        balances[msg.sender] += msg.value;
        totalInvested += msg.value;
        totalFunds += msg.value;
        emit InvestmentReceived(msg.sender, msg.value);

        if (!isInvestor[msg.sender]) {
            investors.push(msg.sender);
            isInvestor[msg.sender] = true; // Mark this address as an investor
        }
    }

    function withdraw(uint256 amount) public nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(totalFunds >= amount, "Insufficient total funds");
        payable(msg.sender).transfer(amount);
        balances[msg.sender] -= amount;
        totalFunds -= amount;
        emit WithdrawalMade(msg.sender, amount);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }

    function makeInvestment(uint amountOutMin, uint deadline) public payable onlyOwner {
        require(msg.value > 0, "Must send ETH to make investment");

        address[] memory path = new address[](2);
        path[0] = IUniswapV2Router(UNISWAP_V2_ROUTER).WETH();
        path[1] = investmentToken;

        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            address(this),
            deadline
        );

        emit InvestmentMade(amountOutMin, deadline);
    }

    function addProfits(uint256 amount) public payable onlyOwner {
        require(msg.value == amount, "Amount does not match sent value");
        totalFunds += amount;
        emit ProfitsAdded(amount);
    }

    function distributeProfits() public onlyOwner {
        uint256 totalProfit = address(this).balance - totalInvested;
        require(totalProfit > 0, "No profits to distribute");

        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 investorShare = balances[investor] * 1e18 / totalInvested;
            uint256 investorProfit = totalProfits * investorShare / 1e18;

            balances[investor] += investorProfit;
            totalFunds += investorProfit;
        }

        totalInvested = totalFunds;
    }

    // Allows investors to withdraw their original investment in case of an emergency
    function emergencyWithdraw() public nonReentrant whenPaused {
        uint256 investedAmount = balances[msg.sender];
        require(investedAmount > 0, "No funds to withdraw");

        balances[msg.sender] = 0; // Reset the investor's balance to prevent re-entrancy
        totalInvested -= investedAmount; // Update the total invested amount
        totalFunds -= investedAmount; // Update the total funds to reflect the withdrawal

        payable(msg.sender).transfer(investedAmount);
        emit EmergencyWithdrawal(msg.sender, investedAmount);
    }

    // Owner can pause the contract in case of emergency
    function pause() public onlyOwner {
        _pause();
    }

    // Owner can unpause the contract when it's safe to resume operations
    function unpause() public onlyOwner {
        _unpause();
    }

    // Function to manage ERC20 tokens acquired through investments
    function manageInvestmentTokens(address token, uint256 amount) public onlyOwner {
        require(token != address(0), "Invalid token address");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance");

        IERC20(token).transfer(owner, amount);
        emit TokensManaged(token, amount);
    }

    receive() external payable {
        invest();
    }
}
