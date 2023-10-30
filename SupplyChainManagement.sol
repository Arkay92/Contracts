// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/chiru-labs/PBT/blob/main/src/IPBT.sol";
import "https://github.com/chiru-labs/PBT/blob/main/src/ERC721ReadOnly.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

error InvalidSignature();
error NoMintedTokenForChip();
error NoMappedTokenForChip();
error ArrayLengthMismatch();
error SeedingChipDataForExistingToken();
error UpdatingChipForUnsetChipMapping();
error InvalidBlockNumber();
error BlockNumberTooOld();

/**
 * Implementation of PBT where all chipAddress->tokenIds are preset in the contract by the contract owner.
 */
contract PBTSimple is ERC721ReadOnly, IPBT, AccessControl {
    using ECDSA for bytes32;

    address owner;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant SUPPLIER_ROLE = keccak256("SUPPLIER_ROLE");
    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER_ROLE");

    struct TokenData {
        uint256 tokenId;
        address chipAddress;
        bool set;
    }

    /**
     * Mapping from chipAddress to TokenData
     */
    mapping(address => TokenData) _tokenDatas;

    constructor(string memory name_, string memory symbol_) ERC721ReadOnly(name_, symbol_) {
        owner = msg.sender;
    }

    /**
     * Modifiers
     */
    modifier onlyDistributor() {
        require(hasRole(DISTRIBUTOR_ROLE, _msgSender()), "Must have DISTRIBUTOR_ROLE");
        _;
    }

    modifier onlySupplier() {
        require(hasRole(SUPPLIER_ROLE, _msgSender()), "Must have SUPPLIER_ROLE");
        _;
    }

    modifier onlyConsumer() {
        require(hasRole(CONSUMER_ROLE, _msgSender()), "Must have CONSUMER_ROLE");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    // Should only be called for tokenIds that have not yet been minted
    // If the tokenId has already been minted, use _updateChips instead
    // TODO: consider preventing multiple chip addresses mapping to the same tokenId (store a tokenId->chip mapping)
    function _seedChipToTokenMapping(address[] memory chipAddresses, uint256[] memory tokenIds) internal onlySupplier {
        _seedChipToTokenMapping(chipAddresses, tokenIds, true);
    }

    function _seedChipToTokenMapping(
        address[] memory chipAddresses,
        uint256[] memory tokenIds,
        bool throwIfTokenAlreadyMinted
    ) internal onlySupplier {
        uint256 tokenIdsLength = tokenIds.length;
        if (tokenIdsLength != chipAddresses.length) {
            revert ArrayLengthMismatch();
        }
        for (uint256 i = 0; i < tokenIdsLength; ++i) {
            address chipAddress = chipAddresses[i];
            uint256 tokenId = tokenIds[i];
            if (throwIfTokenAlreadyMinted && _exists(tokenId)) {
                revert SeedingChipDataForExistingToken();
            }
            _tokenDatas[chipAddress] = TokenData(tokenId, chipAddress, true);
        }
    }

    // Should only be called for tokenIds that have been minted
    // If the tokenId hasn't been minted yet, use _seedChipToTokenMapping instead
    // Should only be used and called with care and rails to avoid a centralized entity swapping out valid chips.
    // TODO: consider preventing multiple chip addresses mapping to the same tokenId (store a tokenId->chip mapping)
    function _updateChips(address[] calldata chipAddressesOld, address[] calldata chipAddressesNew) internal onlySupplier {
        if (chipAddressesOld.length != chipAddressesNew.length) {
            revert ArrayLengthMismatch();
        }
        for (uint256 i = 0; i < chipAddressesOld.length; ++i) {
            address oldChipAddress = chipAddressesOld[i];
            TokenData memory oldTokenData = _tokenDatas[oldChipAddress];
            if (!oldTokenData.set) {
                revert UpdatingChipForUnsetChipMapping();
            }
            address newChipAddress = chipAddressesNew[i];
            uint256 tokenId = oldTokenData.tokenId;
            _tokenDatas[newChipAddress] = TokenData(tokenId, newChipAddress, true);
            if (_exists(tokenId)) {
                emit PBTChipRemapping(tokenId, oldChipAddress, newChipAddress);
            }
            delete _tokenDatas[oldChipAddress];
        }
    }

    function tokenIdFor(address chipAddress) external view override returns (uint256) {
        uint256 tokenId = tokenIdMappedFor(chipAddress);
        if (!_exists(tokenId)) {
            revert NoMintedTokenForChip();
        }
        return tokenId;
    }

    function tokenIdMappedFor(address chipAddress) public view returns (uint256) {
        if (!_tokenDatas[chipAddress].set) {
            revert NoMappedTokenForChip();
        }
        return _tokenDatas[chipAddress].tokenId;
    }

    // Returns true if the signer of the signature of the payload is the chip for the token id
    function isChipSignatureForToken(uint256 tokenId, bytes memory payload, bytes memory signature)
        public
        view
        override
        returns (bool)
    {
        if (!_exists(tokenId)) {
            revert NoMintedTokenForChip();
        }
        bytes32 signedHash = keccak256(payload).toEthSignedMessageHash();
        address chipAddr = signedHash.recover(signature);
        return _tokenDatas[chipAddr].set && _tokenDatas[chipAddr].tokenId == tokenId;
    }

    //
    // Parameters:
    //    to: the address of the new owner
    //    signatureFromChip: signature(receivingAddress + recentBlockhash), signed by an approved chip
    //
    // Contract should check that (1) recentBlockhash is a recent blockhash, (2) receivingAddress === to, and (3) the signing chip is allowlisted.
    function _mintTokenWithChip(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig)
        internal
        returns (uint256)
    {
        TokenData memory tokenData = _getTokenDataForChipSignature(signatureFromChip, blockNumberUsedInSig);
        uint256 tokenId = tokenData.tokenId;
        _mint(_msgSender(), tokenId);
        emit PBTMint(tokenId, tokenData.chipAddress);
        return tokenId;
    }

    function transferTokenWithChip(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig) public override {
        _transferTokenWithChip(signatureFromChip, blockNumberUsedInSig, false);
    }

    function transferTokenWithChip(
        bytes calldata signatureFromChip,
        uint256 blockNumberUsedInSig,
        bool useSafeTransferFrom
    ) public override onlyDistributor {
        _transferTokenWithChip(signatureFromChip, blockNumberUsedInSig, useSafeTransferFrom);
    }

    function transferTokenToConsumer(uint256 tokenId) public onlyConsumer {
        // Ensure the caller is a consumer and can transfer the token to themselves
        require(ownerOf(tokenId) == _msgSender(), "Caller is not the owner of the token");
        _transfer(ownerOf(tokenId), _msgSender(), tokenId);
    }

    function _transferTokenWithChip(
        bytes calldata signatureFromChip,
        uint256 blockNumberUsedInSig,
        bool useSafeTransferFrom
    ) internal virtual {
        uint256 tokenId = _getTokenDataForChipSignature(signatureFromChip, blockNumberUsedInSig).tokenId;
        if (useSafeTransferFrom) {
            _safeTransfer(ownerOf(tokenId), _msgSender(), tokenId, "");
        } else {
            _transfer(ownerOf(tokenId), _msgSender(), tokenId);
        }
    }

    function _getTokenDataForChipSignature(bytes calldata signatureFromChip, uint256 blockNumberUsedInSig)
        internal
        view
        returns (TokenData memory)
    {
        // The blockNumberUsedInSig must be in a previous block because the blockhash of the current
        // block does not exist yet.
        if (block.number <= blockNumberUsedInSig) {
            revert InvalidBlockNumber();
        }

        unchecked {
            if (block.number - blockNumberUsedInSig > getMaxBlockhashValidWindow()) {
                revert BlockNumberTooOld();
            }
        }

        bytes32 blockHash = blockhash(blockNumberUsedInSig);
        bytes32 signedHash = keccak256(abi.encodePacked(_msgSender(), blockHash)).toEthSignedMessageHash();
        address chipAddr = signedHash.recover(signatureFromChip);

        TokenData memory tokenData = _tokenDatas[chipAddr];
        if (tokenData.set) {
            return tokenData;
        }
        revert InvalidSignature();
    }

    function getMaxBlockhashValidWindow() public pure virtual returns (uint256) {
        return 100;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return interfaceId == type(IPBT).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * Role based functions
     */

    function grantAdminRole(address account) public onlyOwner {
        grantRole(ADMIN_ROLE, account);
    }

    function grantDistributorRole(address account) public onlyRole(ADMIN_ROLE) {
        grantRole(DISTRIBUTOR_ROLE, account);
    }

    function grantSupplierRole(address account) public onlyRole(ADMIN_ROLE) {
        grantRole(SUPPLIER_ROLE, account);
    }

    function grantConsumerRole(address account) public onlyRole(ADMIN_ROLE) {
        grantRole(CONSUMER_ROLE, account);
    }
}
