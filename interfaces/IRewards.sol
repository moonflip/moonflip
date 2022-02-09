// SPDX-License-Identifier: Unlicensed

pragma solidity >=0.6.12;

interface IRewards {
    function getAwardMultiplier(uint256 rand, uint256 percent) external view returns(uint256);
    function random(uint max) external returns(uint);
    function isIncludedInFee(address account) external view returns (bool);
}