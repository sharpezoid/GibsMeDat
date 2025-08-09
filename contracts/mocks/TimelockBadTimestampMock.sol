// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Timelock with invalid timestamp storage
/// @notice Implements interface but returns non-zero timestamp for any id.
contract TimelockBadTimestampMock {
    uint256 public minDelay;
    mapping(bytes32 => mapping(address => bool)) private _roles;

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    constructor(uint256 _delay, address admin, address proposer) {
        minDelay = _delay;
        _roles[TIMELOCK_ADMIN_ROLE][admin] = true;
        _roles[PROPOSER_ROLE][proposer] = true;
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

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _roles[role][account];
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}
