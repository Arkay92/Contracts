// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

contract PacketData {
    struct Packet {
        address source;
        address destination;
        bytes32 data;
        uint timestamp;
        uint size;
        bool isProcessed;
    }

    mapping (address => Packet[]) public packets;

    function addPacket(address _address, address _to, bytes32 _data, uint _timestamp, uint _size) public {
        packets[_to].push(Packet(_address, _to, _data, _timestamp, _size, false));
    }
    
    function getPackets(address _address) public returns (bytes32[] memory, uint[] memory, uint[] memory) {
        Packet[] storage packetArray = packets[_address];

        uint i;
        uint arrayLength = packetArray.length;
        uint[] memory timestampArray = new uint[](arrayLength);
        uint[] memory sizeArray = new uint[](arrayLength);
        bytes32[] memory dataArray = new bytes32[](arrayLength);

        for (i = 0; i < arrayLength; i++) {
            Packet storage packet = packetArray[i];
            if(!packet.isProcessed) {
                packet.isProcessed = true;
                dataArray[i] = packet.data;
                timestampArray[i] = packet.timestamp;
                sizeArray[i] = packet.size;
            }
        }
        return (dataArray, timestampArray, sizeArray);
    }
}