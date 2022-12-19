// SPDX-License-Identifier: MIT
// Project Name - NFT Tickets

pragma solidity 0.8.17;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Ticket is ERC721A, Ownable {
    using Strings for uint256;

    struct TicketInfo {
        uint256 tokenId;
        uint256 eventId;
        uint256 quantity;
        bool isValid;
    }
    
    string private baseURI;

    uint256 public ticketPrice = 0.3 ether;
    bool public mintStarted = false;
    
    uint256 private constant MAX_SUPPLY = 10000;

    address payable immutable private eventAddress = payable(0xddC3A364260e619316E0A5dE60ef00326E8F164d);
    address payable immutable private artistAddress = payable(0x5039CDa148fDd50818D5Eb8dBfd8bE0c0Bd1B082);

    mapping (address => TicketInfo[]) public tickets;

    // ====== Constructor Used to Initialise State Values =======
    constructor(string memory _initBaseURI) ERC721A("NFT Ticket", "NFTT") {
        require(bytes(_initBaseURI).length > 0, "[Error] Base URI Cannot Be Blank");

        baseURI = _initBaseURI;
    }

    // ===== Check Caller Is User =====
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "[Error] Function cannot be called by a contract");
        _;
    }

    // ====== Check Value Isnt Zero =====
    modifier notZero(uint256 quantity) {
        unchecked {
            require(quantity > 0, "[Error] Quantity / Price cannot be zero");
        }
        _;
    }

    // ===== Check Not Null Value =======
    modifier notNull(string memory str){
        unchecked {
            require(bytes(str).length > 0, "[Error] Null Value Received");
        }
        _;
    }

    // ===== Mint =====
    function mint(uint256 quantity, uint256 eventId) external payable notZero(quantity) callerIsUser {
        require(mintStarted, "[Error] Public Mint Not Started");

        unchecked {
            require(msg.value >= ticketPrice * quantity, "[Error] Not enough funds supplied");
        }

        _mint(msg.sender, quantity);
        
        tickets[msg.sender][totalSupply()] = TicketInfo(totalSupply(), eventId, quantity, true);

        sendFunds(msg.value);
    }

    // ===== Function to Allow Ticket Cancellation =====
    function cancelTicket(uint256 ticketId) public callerIsUser {
        address owner = ERC721A.ownerOf(ticketId);
        require(msg.sender == owner, "[Error] Only the ticket holder can cancel");

        tickets[msg.sender][ticketId].isValid = false;
        delete tickets[msg.sender][ticketId];
    }

    // ===== Function to Check Ticket is Valid
    function checkValid(uint256 ticketId, uint256 eventId, address ticketHolder) public view returns(bool) {
        return (tickets[ticketHolder][ticketId].isValid && tickets[ticketHolder][ticketId].eventId == eventId);
    }

    // ===== Stop Mint =====
    function stopMint() external onlyOwner {
        mintStarted = false;
    }

    // ===== Turn on public mint =====
    function startMint() external onlyOwner {
        mintStarted = true;
    }

    // ===== Change Mint Price =====
    function setMintPrice(uint256 value) notZero(value) external onlyOwner {
        ticketPrice = value;
    }

    // ===== Change Base URI =====
    function setBaseURI(string memory newBaseURI) external onlyOwner notNull(newBaseURI){
        baseURI = newBaseURI;
    }

    // ===== Change Not Revealed URI =====
    function withdraw() external onlyOwner {
        sendFunds(address(this).balance);
    }

    // ===== Set Start Token ID =====
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    // ===== Set Token URI =====
    function tokenURI(uint256 tokenId) public view virtual override(ERC721A) returns (string memory) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    // ===== Split Funds =====
    function sendFunds(uint256 _totalMsgValue) internal {
        (bool s1,) = eventAddress.call{value: (_totalMsgValue * 75) / 100}("");
        (bool s2,) = artistAddress.call{value: (_totalMsgValue * 25) / 100}("");
        require(s1 && s2, "[Error] Payment Splitter Failure");
    }

    // ===== Fallbacks =====
    receive() external payable {
        sendFunds(address(this).balance);
    }

    fallback() external payable {
        sendFunds(address(this).balance);
    }

    /**
     * @dev See {ERC721A-transferFrom}.
     *
     * Requirements:
     *
     * - Stop invalid tiket being sold
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        if(tickets[from][tokenId].isValid) {
            super.transferFrom(from, to, tokenId);
        } 
    }
}