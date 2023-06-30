// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./BankReserve.sol";

contract LiquidityPool is Ownable, ReentrancyGuard {
    AggregatorV3Interface public goldOracle;
    AggregatorV3Interface public silverOracle;

    uint256 public goldReserve;
    uint256 public silverReserve;

    mapping(uint256 => bool) public depositedNFTs;

    BankReserve public bankReserve;

    constructor(address _bankReserve) {
        goldOracle = AggregatorV3Interface(0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6);
        silverOracle = AggregatorV3Interface(0x379589227b15F1a12195D3f2d90bBc9F31f95235);
        bankReserve = BankReserve(_bankReserve);
    }

    function getGoldPrice() public view returns (uint256) {
        (, int256 price, , , ) = goldOracle.latestRoundData();
        require(price > 0, "Invalid gold price");
        return uint256(price);
    }

    function getSilverPrice() public view returns (uint256) {
        (, int256 price, , , ) = silverOracle.latestRoundData();
        require(price > 0, "Invalid silver price");
        return uint256(price);
    }

    function getExchangeRate() public view returns (uint256) {
        uint256 goldPrice = getGoldPrice();
        uint256 silverPrice = getSilverPrice();

        return (goldPrice * goldReserve + silverPrice * silverReserve) / (goldReserve + silverReserve);
    }

    function depositNFT(uint256 _tokenId) external nonReentrant {
        require(!depositedNFTs[_tokenId], "NFT already deposited");
        (, , uint256 weight, ) = bankReserve.bullionData(_tokenId);
        goldReserve += weight;
        depositedNFTs[_tokenId] = true;
    }

    function withdrawNFT(uint256 _tokenId) external nonReentrant {
        require(depositedNFTs[_tokenId], "NFT not deposited");
        (, , uint256 weight, ) = bankReserve.bullionData(_tokenId);
        require(weight <= goldReserve, "Insufficient gold reserves for NFT");
        goldReserve -= weight;
        depositedNFTs[_tokenId] = false;
    }
}
