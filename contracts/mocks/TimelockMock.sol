// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Timelock Mock
/// @notice Minimal timelock returning a fixed delay, used for tests.
contract TimelockMock {
    /// @notice Minimum delay returned by the timelock.
    uint256 public minDelay;

    /// @param _delay Initial delay to report.
    constructor(uint256 _delay) {
        minDelay = _delay;
    }

    /// @notice Fetch the configured delay.
    function getMinDelay() external view returns (uint256) {
        return minDelay;
    }

    /// @notice Mimic TimelockController's hashOperation.
    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32) {
        return keccak256(abi.encode(target, value, keccak256(data), predecessor, salt));
    }
}
