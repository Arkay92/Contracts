// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./LiquidityPool.sol";

contract CBDCToken is ERC20Pausable, Ownable {
    uint8 public constant DECIMALS = 18;
    LiquidityPool public liquidityPool;

    constructor(address _liquidityPool) ERC20("CBDC Token", "CBDC") {
        liquidityPool = LiquidityPool(_liquidityPool);
    }

    function mint(address _recipient, uint256 _amount) external onlyOwner {
        _mint(_recipient, _amount);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function burn(uint256 _amount) public onlyOwner {
        _burn(owner(), _amount);
    }

    function getExchangeRate() public view returns (uint256) {
        return liquidityPool.getExchangeRate();
    }

    // Override the transfer and transferFrom functions to adjust the token amount based on the exchange rate
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        uint256 exchangedAmount = _amount * getExchangeRate();
        return super.transfer(_recipient, exchangedAmount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        uint256 exchangedAmount = _amount * getExchangeRate();
        return super.transferFrom(_sender, _recipient, exchangedAmount);
    }
}
