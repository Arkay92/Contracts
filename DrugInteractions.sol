// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract DrugInteractionSimulator {
    struct Drug {
        string name;
        string description;
        string mechanismOfAction;
        string[] sideEffects;
        string dosageForm;
        uint halfLife;
        string[] contraindications; // Drugs that should not be combined with this drug
        string[] enzymeInducers; // Drugs that enhance metabolic activity
        string[] enzymeInhibitors; // Drugs that reduce metabolic activity
        string classification;
    }

    struct Interaction {
        string drug1;
        string drug2;
        string interactionType;
        string severity;
        uint timestamp;
    }

    address public admin;
    mapping(string => Drug) private drugs;
    Interaction[] public interactionHistory;

    // Events
    event DrugAdded(string name);
    event InteractionCheck(string drug1, string drug2, string interactionType, string severity);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not authorized");
        _;
    }

    // Function to add a new drug
    function addDrug(
        string memory name, 
        string memory description,
        string memory mechanismOfAction,
        string[] memory sideEffects,
        string memory dosageForm,
        uint halfLife,
        string[] memory contraindications, 
        string[] memory enzymeInducers, 
        string[] memory enzymeInhibitors,
        string memory classification
    ) public onlyAdmin {
        drugs[name] = Drug(name, description, mechanismOfAction, sideEffects, dosageForm, halfLife, contraindications, enzymeInducers, enzymeInhibitors, classification);
        emit DrugAdded(name);
    }

    // Function to check for drug interactions
    function checkInteraction(string memory drug1, string memory drug2) public {
        string memory severity;
        // Check for contraindications
        if (_isInList(drugs[drug1].contraindications, drug2)) {
            severity = "High";
            emit InteractionCheck(drug1, drug2, "Contraindication", severity);
            _logInteraction(drug1, drug2, "Contraindication", severity);
            return;
        }
        // Check for enzyme inducer interactions
        if (_isInList(drugs[drug1].enzymeInducers, drug2)) {
            severity = "Medium";
            emit InteractionCheck(drug1, drug2, "Enzyme Inducer", severity);
            _logInteraction(drug1, drug2, "Enzyme Inducer", severity);
            return;
        }
        // Check for enzyme inhibitor interactions
        if (_isInList(drugs[drug1].enzymeInhibitors, drug2)) {
            severity = "Medium";
            emit InteractionCheck(drug1, drug2, "Enzyme Inhibitor", severity);
            _logInteraction(drug1, drug2, "Enzyme Inhibitor", severity);
            return;
        }
        severity = "None";
        emit InteractionCheck(drug1, drug2, "No Interaction", severity);
        _logInteraction(drug1, drug2, "No Interaction", severity);
    }

    // Helper function to check if a string is in a list
    function _isInList(string[] memory list, string memory item) private pure returns (bool) {
        for (uint i = 0; i < list.length; i++) {
            if (keccak256(abi.encodePacked(list[i])) == keccak256(abi.encodePacked(item))) {
                return true;
            }
        }
        return false;
    }

    // Helper function to log interactions
    function _logInteraction(string memory drug1, string memory drug2, string memory interactionType, string memory severity) private {
        interactionHistory.push(Interaction(drug1, drug2, interactionType, severity, block.timestamp));
    }
}
