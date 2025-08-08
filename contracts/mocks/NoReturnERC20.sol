// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ERC20 token without return values
/// @notice Simplified token used for testing SafeERC20 interactions with non-standard tokens.
contract NoReturnERC20 {
    string public name = "NoReturn";
    string public symbol = "NRET";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /// @notice Mint tokens for testing.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    /// @notice Transfer tokens.
    /// @param to Recipient address.
    /// @param amount Amount to transfer.
    function transfer(address to, uint256 amount) external {
        _transfer(msg.sender, to, amount);
    }

    /// @notice Transfer tokens from an approved address.
    /// @param from Source address.
    /// @param to Recipient address.
    /// @param amount Amount to transfer.
    function transferFrom(address from, address to, uint256 amount) external {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
    }

    /// @notice Approve a spender.
    /// @param spender The address allowed to spend.
    /// @param amount The amount approved.
    function approve(address spender, uint256 amount) external {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}
