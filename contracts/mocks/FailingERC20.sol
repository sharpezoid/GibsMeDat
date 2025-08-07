// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title FailingERC20
/// @notice ERC20 token that can be configured to fail transfers for testing.
contract FailingERC20 is ERC20 {
    bool public shouldFail;

    constructor() ERC20("Fail", "FAIL") {}

    /// @notice Mint tokens for testing.
    /// @param to The recipient address.
    /// @param amount The amount to mint.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Toggle whether transfers should fail.
    /// @param v True to make transfers fail, false to allow.
    function setShouldFail(bool v) external {
        shouldFail = v;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (shouldFail) {
            return false;
        }
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (shouldFail) {
            return false;
        }
        return super.transferFrom(from, to, amount);
    }
}
