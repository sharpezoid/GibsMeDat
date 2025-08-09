// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Timelock Mock
/// @notice Minimal timelock returning a fixed delay, used for tests.
contract TimelockMock {
    /// @notice Minimum delay returned by the timelock.
    uint256 public minDelay;
    mapping(bytes32 => uint256) private _timestamps;
    mapping(bytes32 => mapping(address => bool)) private _roles;

    bytes32 public constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    /// @param _delay Initial delay to report.
    /// @param admin Address granted the admin role.
    /// @param proposer Address granted the proposer role.
    constructor(uint256 _delay, address admin, address proposer) {
        minDelay = _delay;
        _roles[TIMELOCK_ADMIN_ROLE][admin] = true;
        _roles[PROPOSER_ROLE][proposer] = true;
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

    function getTimestamp(bytes32 id) external view returns (uint256) {
        return _timestamps[id];
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _roles[role][account];
    }

    function supportsInterface(bytes4) external pure returns (bool) {
        return true;
    }
}
