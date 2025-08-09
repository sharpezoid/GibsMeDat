// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ITimelockController is IERC165 {
    function getMinDelay() external view returns (uint256);

    function hashOperation(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external pure returns (bytes32);

    function getTimestamp(bytes32 id) external view returns (uint256);

    function hasRole(bytes32 role, address account) external view returns (bool);
}

/// @title Gibs Me Dat Token
/// @notice Satirical meme token of the people. Features a 0.69% transfer tax
/// that redistributes wealth, funds the treasury, and sends some to the Gulag.
contract GibsMeDatToken is ERC20, ERC20Burnable, ERC20Permit, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant INITIAL_SUPPLY = 6_942_080_085 * 10 ** 18;
    uint256 public constant TAX_DENOMINATOR = 10_000; // basis points
    uint256 public transferTax = 69; // 0.69%

    uint256 public reflectionTax = 30; // 0.3%
    uint256 public treasuryTax = 30; // 0.3%
    uint256 public burnTax = 9;      // 0.09%
    uint256 public maxTotalTax = 500; // 5%
    uint256 public constant MAX_TAX_CAP = 500; // absolute ceiling
    uint256 public constant TAX_RAISE_DELAY = 2 days;
    uint256 public pendingMaxTotalTax;
    uint256 public maxTotalTaxChangeTime;

    address public treasury; // Treasury wallet controlled by comrades
    address public governance; // Governance contract managing owner functions
    address public constant DEAD = address(0xdead);

    // Reflection accounting using a dividend-like model
    uint256 public reflectionPerToken; // scaled by 1e18
    mapping(address => uint256) public reflectionCredited;
    mapping(address => uint256) public reflectionBalance;
    mapping(address => bool) public isTaxExempt;
    uint256 public totalPendingReflection;
    uint256 public taxExemptSupply;

    uint256 public maxTransferAmount;

    event TreasuryChanged(address indexed previous, address indexed current);
    event GovernanceTransferred(address indexed previous, address indexed current);
    event ComradeReward(uint256 amount);
    event GloriousContribution(uint256 amount);
    event ToGulag(uint256 amount);
    event RedistributionOfWealth(address indexed kulak, uint256 amount);
    event LongLiveTheTokenomics(address gloriousLeader);
    event HoardersPunished(address bourgeoisie, uint256 penalty);
    event ReflectionClaimed(address indexed comrade, uint256 amount);
    event TaxRatesUpdated(uint256 reflection, uint256 treasury, uint256 burn);
    event MaxTotalTaxUpdated(uint256 amount);
    event MaxTotalTaxChangeScheduled(uint256 amount, uint256 executeAfter);
    event MaxTotalTaxChangeCancelled(uint256 amount, uint256 scheduledTime);
    event TaxExemptionUpdated(address indexed account, bool isExempt);
    event MaxTransferAmountUpdated(uint256 amount);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    bytes32 private constant TIMELOCK_ADMIN_ROLE = keccak256("TIMELOCK_ADMIN_ROLE");
    bytes32 private constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");

    constructor(address _treasury)
        ERC20("Gibs Me Dat", "GIBS")
        ERC20Permit("Gibs Me Dat")
    {
        require(_treasury != address(0), "treasury zero");
        _enforceTimelock(_treasury);
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
    /// @dev The treasury must be governed by a timelock contract.
    function setTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "treasury zero");
        _enforceTimelock(newTreasury);
        emit TreasuryChanged(treasury, newTreasury);
        treasury = newTreasury;
    }

    /// @notice Hand control of owner functions to a governance contract.
    /// @param newGovernance Address of the `GibsTreasuryDAO` or multisig.
    function setGovernance(address newGovernance) external onlyOwner {
        require(newGovernance != address(0), "governance zero");
        require(newGovernance.code.length > 0, "governance not contract");
        emit GovernanceTransferred(governance, newGovernance);
        governance = newGovernance;
        transferOwnership(newGovernance);
    }

    function _enforceTimelock(address account) internal view {
        require(account.code.length > 0, "treasury not timelock");
        try IERC165(account).supportsInterface(type(ITimelockController).interfaceId) returns (bool ok) {
            require(ok, "treasury not timelock");
        } catch {
            revert("treasury not timelock");
        }
        try ITimelockController(account).getMinDelay() returns (uint256 delay) {
            require(delay >= TAX_RAISE_DELAY, "timelock delay too low");
            bytes32 id = ITimelockController(account).hashOperation(
                address(0),
                0,
                "",
                bytes32(0),
                bytes32(0)
            );
            try ITimelockController(account).getTimestamp(id) returns (uint256 ts) {
                require(ts == 0, "treasury not timelock");
            } catch {
                revert("treasury not timelock");
            }
            require(
                ITimelockController(account).hasRole(TIMELOCK_ADMIN_ROLE, owner()),
                "owner lacks admin role"
            );
            require(
                ITimelockController(account).hasRole(PROPOSER_ROLE, owner()),
                "owner lacks proposer role"
            );
        } catch {
            revert("treasury not timelock");
        }
    }

    /// @notice Update tax rates in basis points.
    function setTaxRates(
        uint256 _reflectionTax,
        uint256 _treasuryTax,
        uint256 _burnTax
    ) external onlyOwner {
        uint256 total = _reflectionTax + _treasuryTax + _burnTax;
        require(total <= maxTotalTax, "tax too high");
        reflectionTax = _reflectionTax;
        treasuryTax = _treasuryTax;
        burnTax = _burnTax;
        transferTax = total;
        emit TaxRatesUpdated(_reflectionTax, _treasuryTax, _burnTax);
    }

    /// @notice Schedule an increase of the max total tax. Takes effect after delay.
    function scheduleMaxTotalTaxIncrease(uint256 amount) external onlyOwner {
        require(amount <= MAX_TAX_CAP, "max tax too high");
        require(amount > maxTotalTax, "must increase");
        pendingMaxTotalTax = amount;
        maxTotalTaxChangeTime = block.timestamp + TAX_RAISE_DELAY;
        emit MaxTotalTaxChangeScheduled(amount, maxTotalTaxChangeTime);
    }

    /// @notice Cancel a scheduled increase of the max total tax.
    function cancelMaxTotalTaxIncrease() external onlyOwner {
        uint256 amount = pendingMaxTotalTax;
        uint256 scheduledTime = maxTotalTaxChangeTime;
        pendingMaxTotalTax = 0;
        maxTotalTaxChangeTime = 0;
        emit MaxTotalTaxChangeCancelled(amount, scheduledTime);
    }

    /// @notice Set the maximum total tax rate in basis points.
    /// @dev Increases require prior scheduling and timelock expiration.
    function setMaxTotalTax(uint256 amount) external onlyOwner {
        require(amount <= MAX_TAX_CAP, "max tax too high");
        if (amount > maxTotalTax) {
            require(amount == pendingMaxTotalTax, "amount not scheduled");
            require(block.timestamp >= maxTotalTaxChangeTime, "timelock active");
            pendingMaxTotalTax = 0;
            maxTotalTaxChangeTime = 0;
        }
        maxTotalTax = amount;
        emit MaxTotalTaxUpdated(amount);
    }

    /// @notice Whitelist or remove an address from tax and max transfer.
    function setTaxExempt(address account, bool exempt) external onlyOwner {
        if (isTaxExempt[account] != exempt) {
            _updateReflection(account);
            if (
                account != address(this) &&
                account != DEAD &&
                account != treasury
            ) {
                uint256 bal = balanceOf(account);
                if (exempt) {
                    taxExemptSupply += bal;
                } else {
                    taxExemptSupply -= bal;
                }
            }
            isTaxExempt[account] = exempt;
            emit TaxExemptionUpdated(account, exempt);
        }
    }

    /// @notice Set the maximum transfer amount. Zero disables the limit.
    function setMaxTransferAmount(uint256 amount) external onlyOwner {
        maxTransferAmount = amount;
        emit MaxTransferAmountUpdated(amount);
    }

    /// @notice Pause token transfers.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause token transfers.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Rescue tokens accidentally sent to this contract.
    /// @dev GIBS tokens reserved for reflections cannot be rescued.
    function rescueTokens(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "to zero");
        if (token == address(this)) {
            uint256 available = balanceOf(address(this)) - totalPendingReflection;
            require(amount <= available, "reflection owed");
            super._transfer(address(this), to, amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
        emit TokensRescued(token, to, amount);
    }

    /// @notice Claim accumulated reflections.
    function claimReflection() external nonReentrant {
        _updateReflection(msg.sender);
        uint256 amount = reflectionBalance[msg.sender];
        require(amount > 0, "nothing to claim");
        reflectionBalance[msg.sender] = 0;
        require(balanceOf(address(this)) >= totalPendingReflection, "insufficient balance");
        totalPendingReflection -= amount;
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

    function _syncReflection(address account) internal {
        reflectionCredited[account] = balanceOf(account) * reflectionPerToken / 1e18;
    }

    function _pendingReflection(address account) internal view returns (uint256) {
        if (isTaxExempt[account]) {
            return 0;
        }
        uint256 calc = balanceOf(account) * reflectionPerToken / 1e18;
        if (calc < reflectionCredited[account]) {
            return 0;
        }
        return calc - reflectionCredited[account];
    }

    function _distributeReflection(uint256 amount) internal {
        uint256 supply =
            totalSupply() -
            balanceOf(address(this)) -
            balanceOf(DEAD) -
            balanceOf(treasury) -
            taxExemptSupply;
        if (supply > 0) {
            reflectionPerToken += (amount * 1e18) / supply;
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
        whenNotPaused
    {
        if (
            from != address(0) &&
            isTaxExempt[from] &&
            from != address(this) &&
            from != DEAD &&
            from != treasury
        ) {
            taxExemptSupply -= amount;
        }
        if (
            to != address(0) &&
            isTaxExempt[to] &&
            to != address(this) &&
            to != DEAD &&
            to != treasury
        ) {
            taxExemptSupply += amount;
        }
        if (to == address(0)) {
            _updateReflection(from);
        }
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._afterTokenTransfer(from, to, amount);
        if (to == address(0)) {
            _syncReflection(from);
        }
    }

    /// @dev Overrides the ERC20 _transfer to take taxes and handle reflections
    function _transfer(address sender, address recipient, uint256 amount)
        internal
        override
    {
        require(
            maxTransferAmount == 0 ||
                isTaxExempt[sender] ||
                isTaxExempt[recipient] ||
                amount <= maxTransferAmount,
            "max transfer exceeded"
        );

        _updateReflection(sender);
        _updateReflection(recipient);

        if (isTaxExempt[sender] || isTaxExempt[recipient] || transferTax == 0) {
            super._transfer(sender, recipient, amount);
        } else {
            uint256 reflectionFee = (amount * reflectionTax) / TAX_DENOMINATOR;
            uint256 treasuryFee = (amount * treasuryTax) / TAX_DENOMINATOR;
            uint256 burnFee = (amount * burnTax) / TAX_DENOMINATOR;
            uint256 fee = reflectionFee + treasuryFee + burnFee;
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
                totalPendingReflection += reflectionFee;
                emit ComradeReward(reflectionFee);
            }

            if (fee > 0) {
                emit RedistributionOfWealth(sender, fee);
                emit HoardersPunished(sender, fee);
            }
        }

        _syncReflection(sender);
        _syncReflection(recipient);
    }
}

