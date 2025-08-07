// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title GasGuzzler
/// @notice Receives ETH and verifies more than 2300 gas is forwarded.
contract GasGuzzler {
    uint256 public gasLeft;

    receive() external payable {
        uint256 g = gasleft();
        require(g > 2300, "not enough gas");
        gasLeft = g;
    }
}
