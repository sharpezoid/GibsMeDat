// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../GibsMeDatToken.sol";
import "./ReentrantToken.sol";

/// @title RescueTokensReentrancyAttacker
/// @notice Helper contract set as token owner to attempt reentrancy on rescueTokens.
contract RescueTokensReentrancyAttacker {
    GibsMeDatToken public immutable token;
    ReentrantToken public immutable reToken;

    constructor(GibsMeDatToken _token, ReentrantToken _reToken) {
        token = _token;
        reToken = _reToken;
    }

    /// @notice Initiate the rescue attack.
    /// @param amount Amount of reentrant tokens to rescue.
    function attack(uint256 amount) external {
        token.rescueTokens(address(reToken), address(this), amount);
    }

    /// @notice Called by the reentrant token during transfer to reenter rescueTokens.
    /// @param amount Amount to attempt rescuing again.
    function reenter(uint256 amount) external {
        token.rescueTokens(address(reToken), address(this), amount);
    }
}

