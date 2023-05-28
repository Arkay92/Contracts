// SPDX-License-Identifier: MIT
// Created by Robert McMenemy

pragma solidity ^0.8.14;

import "https://raw.githubusercontent.com/chiru-labs/ERC721A/main/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

contract SoftwareLicense is ERC721A, Ownable, ReentrancyGuard {
	// Use strings for uints to allow easier conversion to string
    using Strings for uint256;

    // Struct to hold info about a token
    struct TokenInfo {
        uint256 timeMinted;
        uint256 subscriptionLength;
        uint256 lastRenewal;
        string status;
    }

    // Set starter variables
    bool public mintStarted = false;
    uint256 trialLength = 7 days;
    uint256 public licenceCost = 0.15 ether;

    // Mapping to hold info for each token id
    mapping(uint256 => TokenInfo) private tokenData;

    // Mapping to hold token against user
    mapping(address => uint256) private tokenHoldings;

    // Token name and ticker set in constructor params
    constructor() ERC721A("Software License: ACME CO.", "SLCN") { }

     // Dev mint 
    function devMint(uint8 quantity, string memory status) external onlyOwner {
        uint256 i = totalSupply();
        uint256 newQuantity = i + quantity;

        _mint(msg.sender, quantity);    

        do {
            setTokenInfo(i, status);

            ++i;
        } while (i <= newQuantity);
    }

    // Public mint
    function mint() external payable nonReentrant {
        uint256 nextID = totalSupply() + 1;

        _mint(msg.sender, 1);   

        setTokenInfo(nextID, "Trial");

        tokenHoldings[msg.sender] = nextID;
    }

	// Override _startTokenId() function of ERC721A
	function _startTokenId() internal view virtual override returns (uint256) {
		return 1;
	}

	// Override tokenURI() function of ERC721A with custom on chain metadata
	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        bytes memory dataURI = abi.encodePacked(
            '{',
                '"description": "A license for ACME Co. Software",', 
                '"external_url": "https://acmeco.com",', 
                '"image": "https://bafkreifh6hd2fv7fi5rtczovbjc7gefvvr3qbafnavufi5r36sevrmnvn4.ipfs.nftstorage.link/",', 
                '"name": "ACME Co. License",',
                '"attributes": [',
                    '{ "Status":', tokenData[tokenId].status, '},',
                    '{ "Time Minted":', tokenData[tokenId].timeMinted, '},',
                    '{ "Subscription Length":', tokenData[tokenId].subscriptionLength, '}',
                    '{ "Last Renewal":', tokenData[tokenId].lastRenewal, '}'
                ']',
            '}'
        );
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );
	}

	// Helper function to set token info
    function setTokenInfo(uint256 tokenID, string memory status) internal {
        tokenData[tokenID].timeMinted = block.timestamp;
        tokenData[tokenID].lastRenewal = block.timestamp;
        tokenData[tokenID].status = status;

        if(keccak256(abi.encodePacked(status)) == keccak256(abi.encodePacked("Paid"))) tokenData[tokenID].subscriptionLength = 365 days;
        if(keccak256(abi.encodePacked(status)) == keccak256(abi.encodePacked("Trial"))) tokenData[tokenID].subscriptionLength = trialLength;
    }

    // Function to let license holders buy subscriptions from their trial tokens
    function buyLicense() external payable {
        tokenData[tokenHoldings[msg.sender]].status = "Paid";
        tokenData[tokenHoldings[msg.sender]].subscriptionLength = 365 days;
    }

    // Allow owner to toggle mint status of trials
    function toggleMintStatus() external onlyOwner {
        mintStarted = !mintStarted;
    }

    // Allow owner to change price of full license
    function setLicenseCost(uint256 value) external onlyOwner {
        licenceCost = value;
    }

    // Function to return token id the user holds
    function getUserToken(address user) external view onlyOwner returns(TokenInfo memory) {
        return tokenData[tokenHoldings[user]];
    }

	// Function to send funds to owner
	function sendFunds(uint256 _totalMsgValue) public payable {
		(bool s1,) = payable(address(owner())).call{value: _totalMsgValue}("");
		require(s1, "Transfer failed.");
	}

	// Withdraw
	function withdraw() external onlyOwner nonReentrant {
		sendFunds(address(this).balance);
	}

	// Recieve
	receive() external payable {
		sendFunds(address(this).balance);
	}

	// fallback
	fallback() external payable {
		sendFunds(address(this).balance);
	}

    // Check user only holds one token
    // Check token is being sold if it is then only allow active tokens to be transferred
    // If token is passed its active period deactivate it
    function transferFrom(address from, address to, uint256 tokenId) public payable virtual override {
        if(from != address(owner()) && from != address(this) && to != address(owner())  && to != address(this)) {
            require(balanceOf(to)< 1, "[Error] User can only hold once license");
            if(msg.value > 0) {
                if(block.timestamp > tokenData[tokenId].lastRenewal + tokenData[tokenId].subscriptionLength) {
                    tokenData[tokenId].status = "Deactivated";
                    tokenData[tokenId].subscriptionLength = 0 days;
                }
                require(keccak256(abi.encodePacked(tokenData[tokenId].status)) == keccak256(abi.encodePacked("Paid")), "[Error] Only active tokens can be sold");
            }
        }
        super.transferFrom(from, to, tokenId);
    }
}
