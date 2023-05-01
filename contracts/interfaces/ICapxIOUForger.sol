//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface ICapxIOUForger {
    function isCapxIOUToken(address iouToken) external view returns(bool);
}