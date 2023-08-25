// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PedersonsCommitment {
    struct Commitment {
        bytes32 commitmentValue;
        bool isSet;
    }

    mapping(uint256 => Commitment) public commitments;

    function commitToNumber(uint256 index, bytes32 commitmentValue) public {
        commitments[index] = Commitment(commitmentValue, true);
    }

    function verifyDuplicate(uint256[] memory indices, bytes32[] memory proof) public view returns (bool) {
        require(indices.length == proof.length, "Mismatched array lengths");
        require(indices.length > 0, "Indices array is empty");
        require(proof.length > 0, "Proof array is empty");
        
        bytes32 root = proof[proof.length - 1];
        
        for (uint256 i = 0; i < indices.length; i++) {
            uint256 index = indices[i];
            Commitment storage commitment = commitments[index];
            require(commitment.isSet, "Commitment not set");
            
            bytes32 commitmentValue = commitment.commitmentValue;
            bytes32 proofElement = proof[i];
            
            if (i % 2 == 0) {
                root = keccak256(abi.encodePacked(root, proofElement));
            } else {
                root = keccak256(abi.encodePacked(proofElement, root));
            }
        }
        
        return root == commitmentValue; // Compare the computed root with the provided commitment value
    }
}
