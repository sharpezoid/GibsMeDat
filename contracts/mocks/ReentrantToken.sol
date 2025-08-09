// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IGibsMeDatToken {
    function rescueTokens(address token, address to, uint256 amount) external;
    function claimReflection() external;
}

interface IRescueTokensReentrancyAttacker {
    function reenter(uint256 amount) external;
}

/// @title ReentrantToken
/// @notice ERC20 token used to test reentrancy against GibsMeDatToken.
contract ReentrantToken is ERC20 {
    enum Action { None, Rescue, Claim }

    IGibsMeDatToken public immutable target;
    Action public action;
    address public attacker;

    constructor(address _target) ERC20("Reentrant", "REENT") {
        target = IGibsMeDatToken(_target);
    }

    /// @notice Mint tokens for testing.
    /// @param to Recipient address.
    /// @param amount Amount to mint.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Set which function to call reentrantly during transfers.
    /// @param a The action to perform.
    function setAction(Action a) external {
        action = a;
    }

    /// @notice Designate the attacker contract used for rescue reentrancy tests.
    /// @param a Address of the attacker contract.
    function setAttacker(address a) external {
        attacker = a;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        bool ok = super.transfer(to, amount);
        if (action == Action.Rescue) {
            IRescueTokensReentrancyAttacker(attacker).reenter(amount);
        } else if (action == Action.Claim) {
            target.claimReflection();
        }
        return ok;
    }
}

