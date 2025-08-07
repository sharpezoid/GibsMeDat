// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ProletariatVault.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ReentrancyAttacker
/// @notice Helper contract to test reentrancy protections in the vault.
contract ReentrancyAttacker is IERC1155Receiver {
    enum Action {
        None,
        Stake,
        Unstake
    }

    ProletariatVault public immutable vault;
    Action public action;
    uint256 public targetId;

    constructor(address _vault) {
        vault = ProletariatVault(_vault);
    }

    /// @notice Approve the vault to spend tokens held by this contract.
    /// @param token ERC20 token to approve.
    /// @param spender Address allowed to spend the tokens.
    /// @param amount Amount of tokens to approve.
    function approveToken(IERC20 token, address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    /// @notice Attempt a reentrant stake call.
    /// @param id Vault identifier.
    /// @param amount Amount of tokens to stake.
    function attackStake(uint256 id, uint256 amount) external {
        targetId = id;
        action = Action.Stake;
        vault.stake(id, amount);
        action = Action.None;
    }

    /// @notice Attempt a reentrant unstake call.
    /// @param id Vault identifier.
    /// @param amount Amount of tokens to stake initially.
    function attackUnstake(uint256 id, uint256 amount) external {
        targetId = id;
        action = Action.Unstake;
        vault.stake(id, amount);
        action = Action.None;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        if (action == Action.Stake) {
            vault.stake(targetId, 1);
        } else if (action == Action.Unstake) {
            vault.unstake(targetId);
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
