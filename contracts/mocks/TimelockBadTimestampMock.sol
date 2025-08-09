// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Timelock with invalid timestamp storage
/// @notice Implements interface but returns non-zero timestamp for any id.
contract TimelockBadTimestampMock {
    uint256 public minDelay;

    constructor(uint256 _delay) {
        minDelay = _delay;
    }

    function getMinDelay() external view returns (uint256) {
        return minDelay;
    }

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32) {
        return keccak256(abi.encode(target, value, keccak256(data), predecessor, salt));
    }

    function getTimestamp(bytes32) external pure returns (uint256) {
        return 1; // invalid: should be 0 for unscheduled operations
    }
}
