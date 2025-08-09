// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Timelock without hashOperation
/// @notice Returns delay but lacks TimelockController interface.
contract TimelockNoHashMock {
    uint256 public minDelay;

    constructor(uint256 _delay) {
        minDelay = _delay;
    }

    function getMinDelay() external view returns (uint256) {
        return minDelay;
    }
}
