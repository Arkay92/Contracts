// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract LiquidityPool is Ownable, ReentrancyGuard {
    AggregatorV3Interface public goldOracle;
    AggregatorV3Interface public silverOracle;
    AggregatorV3Interface public copperOracle;

    uint256 public goldReserve;
    uint256 public silverReserve;
    uint256 public copperReserve;

    constructor() {
        goldOracle = AggregatorV3Interface(0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6);
        silverOracle = AggregatorV3Interface(0x379589227b15F1a12195D3f2d90bBc9F31f95235);
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

    function depositGold(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount > 0, "Invalid amount");
        goldReserve += _amount;
    }

    function depositSilver(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount > 0, "Invalid amount");
        silverReserve += _amount;
    }

    function withdrawGold(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount > 0, "Invalid amount");
        require(_amount <= goldReserve, "Insufficient gold reserves");
        goldReserve -= _amount;
    }

    function withdrawSilver(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount > 0, "Invalid amount");
        require(_amount <= silverReserve, "Insufficient silver reserves");
        silverReserve -= _amount;
    }

    function getExchangeRate() public view returns (uint256) {
        uint256 goldPrice = getGoldPrice();
        uint256 silverPrice = getSilverPrice();
        
        return (goldPrice * goldReserve + silverPrice * silverReserve) / (goldReserve + silverReserve);
    }
}
