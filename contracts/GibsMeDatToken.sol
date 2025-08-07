// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Gibs Me Dat Token
/// @notice Satirical meme token of the people. Features a 0.69% transfer tax
/// that redistributes wealth, funds the treasury, and sends some to the Gulag.
contract GibsMeDatToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant INITIAL_SUPPLY = 6_942_080_085 * 10 ** 18;
    uint256 public constant TAX_DENOMINATOR = 10_000; // basis points
    uint256 public constant TRANSFER_TAX = 69; // 0.69%

    uint256 public constant REFLECTION_TAX = 30; // 0.3%
    uint256 public constant TREASURY_TAX = 30; // 0.3%
    uint256 public constant BURN_TAX = 9;      // 0.09%

    address public treasury; // Treasury wallet controlled by comrades
    address public constant DEAD = address(0xdead);

    // Reflection accounting using a dividend-like model
    uint256 public reflectionPerToken; // scaled by 1e18
    mapping(address => uint256) public reflectionCredited;
    mapping(address => uint256) public reflectionBalance;

    event TreasuryChanged(address indexed previous, address indexed current);
    event ComradeReward(uint256 amount);
    event GloriousContribution(uint256 amount);
    event ToGulag(uint256 amount);
    event RedistributionOfWealth(address indexed kulak, uint256 amount);
    event LongLiveTheTokenomics(address gloriousLeader);
    event HoardersPunished(address bourgeoisie, uint256 penalty);
    event ReflectionClaimed(address indexed comrade, uint256 amount);

    constructor(address _treasury) ERC20("Gibs Me Dat", "GIBS") {
        require(_treasury != address(0), "treasury zero");
        treasury = _treasury;
        _mint(msg.sender, INITIAL_SUPPLY);
        // Initial Gulag burn of 10%
        uint256 gulag = INITIAL_SUPPLY / 10;
        uint256 committee = (INITIAL_SUPPLY * 5) / 100;
        super._transfer(msg.sender, DEAD, gulag);
        super._transfer(msg.sender, treasury, committee);
        emit ToGulag(gulag);
        emit GloriousContribution(committee);
        emit LongLiveTheTokenomics(msg.sender);
    }

    /// @notice Adjust the treasury address. Only Supreme Leader can do this.
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "treasury zero");
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

    /// @notice Claim accumulated reflections.
    function claimReflection() external {
        _updateReflection(msg.sender);
        uint256 amount = reflectionBalance[msg.sender];
        require(amount > 0, "nothing to claim");
        reflectionBalance[msg.sender] = 0;
        super._transfer(address(this), msg.sender, amount);
        emit ReflectionClaimed(msg.sender, amount);
    }

    function _updateReflection(address account) internal {
        uint256 owed = _pendingReflection(account);
        if (owed > 0) {
            reflectionBalance[account] += owed;
        }
        reflectionCredited[account] = balanceOf(account) * reflectionPerToken / 1e18;
    }

    function _pendingReflection(address account) internal view returns (uint256) {
        return balanceOf(account) * reflectionPerToken / 1e18 - reflectionCredited[account];
    }

    function _distributeReflection(uint256 amount) internal {
        uint256 supply = totalSupply() - balanceOf(address(this)) - balanceOf(DEAD) - balanceOf(treasury);
        if (supply > 0) {
            reflectionPerToken += (amount * 1e18) / supply;
        }
    }

    /// @dev Overrides the ERC20 _transfer to take taxes and handle reflections
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        _updateReflection(sender);
        _updateReflection(recipient);

        uint256 fee = (amount * TRANSFER_TAX) / TAX_DENOMINATOR;
        uint256 reflectionFee = (amount * REFLECTION_TAX) / TAX_DENOMINATOR;
        uint256 treasuryFee   = (amount * TREASURY_TAX) / TAX_DENOMINATOR;
        uint256 burnFee       = (amount * BURN_TAX) / TAX_DENOMINATOR;
        uint256 transferAmount = amount - fee;

        super._transfer(sender, recipient, transferAmount);

        if (treasuryFee > 0) {
            super._transfer(sender, treasury, treasuryFee);
            emit GloriousContribution(treasuryFee);
        }
        if (burnFee > 0) {
            super._transfer(sender, DEAD, burnFee);
            emit ToGulag(burnFee);
        }
        if (reflectionFee > 0) {
            super._transfer(sender, address(this), reflectionFee);
            _distributeReflection(reflectionFee);
            emit ComradeReward(reflectionFee);
        }

        if (fee > 0) {
            emit RedistributionOfWealth(sender, fee);
            emit HoardersPunished(sender, fee);
        }

        _updateReflection(sender);
        _updateReflection(recipient);
    }
}

