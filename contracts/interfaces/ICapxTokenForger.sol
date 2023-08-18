//SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface ICapxTokenForger {
    function isTokenPoweredByCapx(address _tokenPoweredByCapx) external view returns(bool);
}