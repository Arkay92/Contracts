// SPDX-License-Identifier: MIT
// Project Name - Spectral Analysis

pragma solidity 0.8.17;

import "./ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SpectralAnalysis is ERC721A, Ownable {
    using Strings for uint256;

    uint256 currentTokenID = totalSupply();

    struct XRFData {
        string element;
        string atomicNumber;
        string intensity;
    }

    struct Painting {
        address owner;
        string name;
        uint256 cost;
        XRFData xrfSignature;
    }

    string private baseURI;

    mapping (uint256 => Painting) public paintings;

    // ====== Constructor Used to Initialise State Values =======
    constructor(string memory _initBaseURI) ERC721A("Spectral Analyser", "SA") {
        require(bytes(_initBaseURI).length > 0, "[Error] Base URI Cannot Be Blank");

        baseURI = _initBaseURI;
    }

    // ===== Check Caller Is User =====
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "[Error] Function cannot be called by a contract");
        _;
    }

    // ===== Check Not Null Value =======
    modifier notNull(string memory str){
        unchecked {
            require(bytes(str).length > 0, "[Error] Null Value Received");
        }
        _;
    }

    // ===== Register Artwork With the Contract =====
    function registerPiece(
        address intendedOwner, 
        string calldata pieceName,
        uint256 cost,
        string[] calldata xrfData
    ) external payable callerIsUser onlyOwner {
        _mint(msg.sender, 1);

        XRFData memory xrf;

        xrf.element = xrfData[0]; 
        xrf.atomicNumber = xrfData[1]; 
        xrf.intensity = xrfData[3]; 
        
        paintings[currentTokenID] = Painting(
            intendedOwner, 
            pieceName, 
            cost, 
            xrf
        );
    }

    // ====== Send Token ID and XRF Data to Verify =======
    function verifyPiece(
        uint256 tokenID, 
        string[] memory xrfData
    ) public view callerIsUser onlyOwner returns(bool) {
        return (
            keccak256(bytes(paintings[tokenID].xrfSignature.element)) == keccak256(bytes(xrfData[0])) &&
            keccak256(bytes(paintings[tokenID].xrfSignature.atomicNumber)) == keccak256(bytes(xrfData[1])) &&
            keccak256(bytes(paintings[tokenID].xrfSignature.intensity)) == keccak256(bytes(xrfData[2]))
        );
    } 

    // ====== Sell Painting ===========
    function sellPainting(
        uint256 tokenID,
        string[] calldata xrfData,
        address recipient
    ) public callerIsUser {
        address owner = ERC721A.ownerOf(tokenID);

        require(msg.sender == owner, "[Error] You are not the owner of the piece");
        
        if(verifyPiece(tokenID, xrfData)) {
            safeTransferFrom(msg.sender, recipient, tokenID);
        }
    }

    // ===== Change Base URI =====
    function setBaseURI(string memory newBaseURI) external onlyOwner notNull(newBaseURI){
        baseURI = newBaseURI;
    }

    // ===== Set Start Token ID =====
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    // ===== Set Token URI =====
    function tokenURI(uint256 tokenId) public view virtual override(ERC721A) returns (string memory) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }
}