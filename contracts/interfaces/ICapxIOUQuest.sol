//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface ICapxIOUQuest {
     function claim(
        bytes32 _messageHash,
        bytes memory _signature,
        address _sender,
        address _receiver
    ) external;
}