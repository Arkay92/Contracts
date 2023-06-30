// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://raw.githubusercontent.com/chiru-labs/ERC721A/main/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityPool.sol";

contract BankReserve is ERC721A, Ownable {
    struct BullionData {
        string assetId;
        string purity;
        uint256 weight;
        uint256 dateOfIntake;
    }

    mapping(uint256 => BullionData) private bullionData;
    uint256[] private allBullionIds;
    LiquidityPool private liquidityPool;

    constructor(string memory _name, string memory _symbol, address _liquidityPool) ERC721A(_name, _symbol) {
        liquidityPool = LiquidityPool(_liquidityPool);
    }

    function mintBullionNFT(
        address _to,
        uint256 _tokenId,
        string memory _assetId,
        string memory _purity,
        uint256 _weight,
        uint256 _dateOfIntake
    ) external onlyOwner {
        _mint(_to, _tokenId);
        bullionData[_tokenId] = BullionData(_assetId, _purity, _weight, _dateOfIntake);
        allBullionIds.push(_tokenId);
        liquidityPool.depositGold(_weight); // Deposit the weight of the bullion into the liquidity pool
    }

    function burnBullionNFT(uint256 _tokenId) external onlyOwner {
        require(_exists(_tokenId), "BullionNFT: Token ID does not exist");
        _burn(_tokenId);
        BullionData memory data = bullionData[_tokenId];
        delete bullionData[_tokenId];
        uint256[] storage allBullion = allBullionIds;
        for (uint256 i = 0; i < allBullion.length; i++) {
            if (allBullion[i] == _tokenId) {
                allBullion[i] = allBullion[allBullion.length - 1];
                allBullion.pop();
                break;
            }
        }
        liquidityPool.withdrawGold(data.weight); // Withdraw the weight of the burnt bullion from the liquidity pool
    }

    function getAllBullion() external view returns (uint256[] memory) {
        return allBullionIds;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
}
