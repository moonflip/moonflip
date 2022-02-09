// SPDX-License-Identifier: Unlicensed

pragma solidity >=0.6.12;

interface IRewardSheet {
    function getAwardMultiplier(uint256 rand) external pure returns (uint256);
    function getPoolGrowthAwardMultiplier(uint256 rand) external pure returns (uint256);
}