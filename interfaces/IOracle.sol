// SPDX-License-Identifier: Unlicensed

pragma solidity >=0.6.12;

interface IOracle {
    function getRandom() external returns (uint);
}