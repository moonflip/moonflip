// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

contract ERC20 {
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}