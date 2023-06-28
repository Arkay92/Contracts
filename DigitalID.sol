// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract DigitalID is ERC721A, Ownable {
    using Strings for uint256;

    mapping(address => mapping(uint256 => bool)) private _soulboundTokens;
    mapping(uint256 => UserDetails) private _encryptedDetails;
    uint256 private _nextTokenIdToBe;
    string public _baseTokenURI = "https://bafkreiemiq52ksij4lvyvffmkx5xclnanp2aiaduyei3ymlqdrlzn37tey.ipfs.nftstorage.link/";

    struct UserDetails {
        bytes32 encryptedHomeAddress;
        bytes32 encryptedAge;
        bytes32 encryptedDOB;
        bytes32 encryptedName;
    }

    constructor() ERC721A("DigitalID", "DIGID") {}

    function mint(
        string memory encryptedHomeAddress,
        string memory encryptedAge,
        string memory encryptedDOB,
        string memory encryptedName
    ) public {
        uint256 tokenId = _nextTokenIdToBe;
        require(!_exists(tokenId), "Token already minted");
        require(balanceOf(msg.sender) == 0, "You already have an ID");
        _mint(msg.sender, 1);
        _soulboundTokens[msg.sender][tokenId] = true;
        _encryptedDetails[tokenId] = UserDetails(
            bytes32(bytes(encryptedHomeAddress)),
            bytes32(bytes(encryptedAge)),
            bytes32(bytes(encryptedDOB)),
            bytes32(bytes(encryptedName))
        );
        _nextTokenIdToBe++;
    }

    function transferFrom(address from, address to, uint256 tokenId) public payable override {
        require(!isSoulbound(from, tokenId), "Token is soulbound");
        require(from == owner() || from == address(this), "Only owner or contract can transfer soulbound token");
        super.transferFrom(from, to, tokenId);
        _soulboundTokens[from][tokenId] = false;
        _soulboundTokens[to][tokenId] = true;
    }

    function isSoulbound(address owner, uint256 tokenId) public view returns (bool) {
        return _soulboundTokens[owner][tokenId];
    }

    function getEncryptedDetails(uint256 tokenId) public view returns (bytes32, bytes32, bytes32) {
        UserDetails memory details = _encryptedDetails[tokenId];
        return (details.encryptedHomeAddress, details.encryptedAge, details.encryptedDOB);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return _baseTokenURI;
	}

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }
    
	function _startTokenId() internal view virtual override returns (uint256) {
		return 1;
	}

    function getTokenInfo(uint256 tokenID) public view returns(string memory) {
        if(msg.sender == ownerOf(tokenID) || msg.sender == owner()) {
            return string(abi.encodePacked(
                "{ Name: ", _encryptedDetails[tokenID].encryptedName , ",",
                "Age: ", _encryptedDetails[tokenID].encryptedAge , ",",
                "DOB: ", _encryptedDetails[tokenID].encryptedDOB , ",",
                "Name:  ", _encryptedDetails[tokenID].encryptedName , "}"
            ));
        } else {
            return '{ "message": "Error not permitted to view" }';
        }
    }
}
