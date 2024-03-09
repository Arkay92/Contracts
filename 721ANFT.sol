// Smart Contract Developed By Robert McMenemy
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "ERC721A/ERC721A.sol";

contract MYNft is ERC721A, Ownable, ReentrancyGuard {
    using Strings for uint256;
    using MerkleProof for bytes32[];

    enum MintState {
        Stopped,
        Public,
        Private
    }

    uint256 private immutable MAX_SUPPLY = 4500;
    uint256 private immutable MAX_PER_WALLET = 3;

    uint256 public privateCost = 0.0001 ether;
    uint256 public cost = 0.001 ether;
    bool public revealedState = false;

    MintState public mintState;

    string private __baseURI;
    string private _notRevealedURI;
    bytes32 private _presaleMerkleRoot;
    bytes32 private _ogMerkleRoot;
    bool public devMintLocked;

    constructor(string memory initBaseURI_, string memory initNotRevealedURI_, bytes32 presaleRoot_)
        ERC721A("MyNft", "MNFT")
        Ownable()
        checkURI(initBaseURI_)
        checkURI(initNotRevealedURI_)
    {
        require(presaleRoot_ != bytes32(0), "[Error] Empty Root");

        __baseURI = initBaseURI_;
        _notRevealedURI = initNotRevealedURI_;
        _presaleMerkleRoot = presaleRoot_;

        // Initialize mint state
        mintState = MintState.Stopped;
    }

    modifier checkURI(string memory str) {
        require(bytes(str).length > 0, "[Error] URI Cannot Be Blank");
        _;
    }

    modifier maxWalletCheck(uint256 quantity) {
        require(uint256(_numberMinted(msg.sender)) + quantity <= MAX_PER_WALLET, "[Error] Max Per Wallet Reached");
        _;
    }

    modifier supplyCheck(uint256 quantity) {
        require(_totalMinted() + quantity <= MAX_SUPPLY, "[Error] Max Mint Reached");
        _;
    }

    modifier checkWhitelisted(bytes32[] memory proof, bytes32 root) {
        require(proof.verify(_presaleMerkleRoot, keccak256(abi.encodePacked(msg.sender))), "[Error] Not whitelisted");
        _;
    }

    modifier checkCost(uint256 totalCost, uint256 quantity) {
        require(msg.value >= totalCost * quantity, "[Error] Not enough funds supplied");
        _;
    }

    modifier checkValue(uint256 value) {
        require(value > 0, "[Error] Value cannot be 0");
        _;
    }

    function privateMint(bytes32[] memory proof, uint8 quantity)
        external
        payable
        maxWalletCheck(quantity)
        supplyCheck(quantity)
        checkWhitelisted(proof, _presaleMerkleRoot)
        checkCost(privateCost, quantity)
        nonReentrant
    {
        require(mintState == MintState.Private, "[Error] Private Mint Not Started");

        _mint(msg.sender, quantity);
        _sendFunds(msg.value);
    }

    function mint(uint8 quantity)
        external
        payable
        maxWalletCheck(quantity)
        supplyCheck(quantity)
        checkCost(cost, quantity)
        nonReentrant
    {
        require(mintState == MintState.Public, "[Error] Public Mint Not Started");

        _mint(msg.sender, quantity);
        _sendFunds(msg.value);
    }


    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return __baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721A) returns (string memory) {
        string memory currentUri = (revealedState == true) ? __baseURI : _notRevealedURI;
        return bytes(currentUri).length > 0 ? string(abi.encodePacked(currentUri, tokenId.toString(), ".json")) : "";
    }

    function lockDevMint() external onlyOwner {
        devMintLocked = true;
    }

    function devMint(uint8 quantity) external onlyOwner supplyCheck(quantity) {
        require(devMintLocked == false, "[Error] Locked");
        _mint(msg.sender, quantity);
    }

    function stopMint() external onlyOwner {
        mintState = MintState.Stopped;
    }

    function turnOnPublicMint() external onlyOwner {
        mintState = MintState.Public;
    }

    function turnOnPrivateMint() external onlyOwner {
        mintState = MintState.Private;
    }

    function toggleReveal() external onlyOwner {
        revealedState = !revealedState;
    }

    function setMerkleRoot(bytes32 root) external onlyOwner {
        require(root.length > 0, "[Error] Empty Root");
        _presaleMerkleRoot = root;
    }

    function setPublicMintPrice(uint256 value) external onlyOwner checkValue(value) {
        cost = value;
    }

    function setPrivateMintPrice(uint256 value) external onlyOwner checkValue(value) {
        privateCost = value;
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner nonReentrant checkURI(newBaseURI) {
        __baseURI = newBaseURI;
    }

    function setNotRevealedURI(string memory newNotRevealedURI)
        external
        onlyOwner
        nonReentrant
        checkURI(newNotRevealedURI)
    {
        _notRevealedURI = newNotRevealedURI;
    }

    function withdraw() external onlyOwner nonReentrant {
        sendFunds(address(this).balance);
    }

    function sendFunds(uint256 _totalAmount) internal {
        address(owner()).transfer(_totalAmount);
    }

    // Including the _safeTransferETH function for completeness
    function _safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "[Error] ETH Transfer Failed");
    }
}
