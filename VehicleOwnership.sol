// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import the ERC721 and ERC721Enumerable interfaces from OpenZeppelin
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VehicleOwnership is ERC721Enumerable, Ownable {
    // Structure to hold historical data of each vehicle
    struct VehicleData {
        uint256 manufacturingTimestamp;
        string supplyChainPath;
        address[] ownershipHistory;
        string[] serviceData;
        mapping(address => bool) approvedTechnicians;
    }

    // Mapping to store historical data for each vehicle
    mapping(uint256 => VehicleData) private vehicleHistory;

    // Mapping to store loyalty points for each vehicle owner
    mapping(address => uint256) private loyaltyPoints;

    // Events
    event VehicleManufactured(uint256 tokenId, uint256 timestamp);
    event OwnershipTransferred(uint256 tokenId, address indexed previousOwner, address indexed newOwner);
    event ServiceDataUpdated(uint256 tokenId, string serviceData, address indexed technician);
    event LoyaltyPointsUpdated(address indexed owner, uint256 points);
    event TechnicianApproved(uint256 tokenId, address indexed technician);
    event TechnicianRevoked(uint256 tokenId, address indexed technician);

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    // Modifier to check approved or owner status
    modifier isApprovedOwner(uint256 tokenID) {
        require(_isApprovedOrOwner(msg.sender, tokenID), "You are not the owner");
        _;
    }

    // Function to mint a new vehicle NFT with initial manufacturing data
    function manufactureVehicle(uint256 manufacturingTimestamp, string calldata supplyChainPath) external onlyOwner {
        uint256 tokenId = totalSupply() + 1; // Derive tokenId dynamically
        _mint(owner(), tokenId);
        vehicleHistory[tokenId].manufacturingTimestamp = manufacturingTimestamp;
        vehicleHistory[tokenId].supplyChainPath = supplyChainPath;
        emit VehicleManufactured(tokenId, manufacturingTimestamp);
    }

    // Function to transfer ownership of a vehicle NFT
    function transferOwnership(uint256 tokenId, address newOwner) external isApprovedOwner(tokenId) {
        _transfer(msg.sender, newOwner, tokenId);
        vehicleHistory[tokenId].ownershipHistory.push(newOwner);
        emit OwnershipTransferred(tokenId, msg.sender, newOwner);
    }

    // Function to update service data of a vehicle by an approved technician
    function updateServiceData(uint256 tokenId, string calldata serviceData) external {
        require(vehicleHistory[tokenId].approvedTechnicians[msg.sender], "You are not an approved technician");
        vehicleHistory[tokenId].serviceData.push(serviceData);
        emit ServiceDataUpdated(tokenId, serviceData, msg.sender);
    }

    // Function to get manufacturing timestamp of a vehicle
    function getManufacturingTimestamp(uint256 tokenId) external view returns (uint256) {
        return vehicleHistory[tokenId].manufacturingTimestamp;
    }

    // Function to get supply chain path of a vehicle
    function getSupplyChainPath(uint256 tokenId) external view returns (string memory) {
        return vehicleHistory[tokenId].supplyChainPath;
    }

    // Function to get ownership history of a vehicle
    function getOwnershipHistory(uint256 tokenId) external view returns (address[] memory) {
        return vehicleHistory[tokenId].ownershipHistory;
    }

    // Function to get service data of a vehicle
    function getServiceData(uint256 tokenId) external view returns (string[] memory) {
        return vehicleHistory[tokenId].serviceData;
    }

    // Function to check if a technician is approved for a vehicle
    function isTechnicianApproved(uint256 tokenId, address technician) external view returns (bool) {
        return vehicleHistory[tokenId].approvedTechnicians[technician];
    }

    // Function to get the loyalty points of the caller
    function getLoyaltyPoints() external view returns (uint256) {
        return loyaltyPoints[msg.sender];
    }

    // Function to update loyalty points for the caller
    function updateLoyaltyPoints(uint256 points) external {
        loyaltyPoints[msg.sender] += points;
        emit LoyaltyPointsUpdated(msg.sender, loyaltyPoints[msg.sender]);
    }

    // Function to approve a service technician to update service data
    function approveTechnician(uint256 tokenId, address technician) external isApprovedOwner(tokenId) {
        vehicleHistory[tokenId].approvedTechnicians[technician] = true;
        emit TechnicianApproved(tokenId, technician);
    }

    // Function to revoke approval of a service technician
    function revokeTechnicianApproval(uint256 tokenId, address technician) external isApprovedOwner(tokenId) {
        vehicleHistory[tokenId].approvedTechnicians[technician] = false;
        emit TechnicianRevoked(tokenId, technician);
    }
}
