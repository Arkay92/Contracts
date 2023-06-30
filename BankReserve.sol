// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://raw.githubusercontent.com/chiru-labs/ERC721A/main/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BankReserve is ERC721A, Ownable {
    struct BullionData {
        string assetId;
        string purity;
        uint256 weight;
        uint256 dateOfIntake;
    }

    mapping(uint256 => BullionData) private bullionData;
    uint256[] private allBullionIds;

    constructor(string memory _name, string memory _symbol) ERC721A(_name, _symbol) {}

    function mintBullionNFT(
        address _to,
        uint256 _tokenId,
        string memory _assetId,
        string memory _purity,
        uint256 _weight,
        uint256 _dateOfIntake
    ) external onlyOwner {
        _mint(_to, 1);
        bullionData[_tokenId] = BullionData(_assetId, _purity, _weight, _dateOfIntake);
        allBullionIds.push(_tokenId);
    }

    function getBullionData(uint256 _tokenId)
        external
        view
        returns (
            string memory,
            string memory,
            uint256,
            uint256
        )
    {
        BullionData memory data = bullionData[_tokenId];
        return (data.assetId, data.purity, data.weight, data.dateOfIntake);
    }

    function burnBullionNFT(uint256 _tokenId) external onlyOwner {
        require(_exists(_tokenId), "BullionNFT: Token ID does not exist");
        _burn(_tokenId);
        delete bullionData[_tokenId];
        uint256[] storage allBullion = allBullionIds;
        for (uint256 i = 0; i < allBullion.length; i++) {
            if (allBullion[i] == _tokenId) {
                allBullion[i] = allBullion[allBullion.length - 1];
                allBullion.pop();
                break;
            }
        }
    }

    function getAllBullion() external view returns (uint256[] memory) {
        return allBullionIds;
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
}
