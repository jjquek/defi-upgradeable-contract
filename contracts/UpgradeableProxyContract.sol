// contracts/MyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// * --------- OPENZEPELLIN PACKAGES -----------
// A straightforward and robust way to implement upgradeable contracts is to extend contracts provided by OpenZepellin. Their contracts have been the subject of much effort and audit.
// See inline comments where these imports are used for specific reasons.
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract UpgradeableProxyContract is Initializable, ERC20Upgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable  {
    // need the interface for ERC20Upgradeable to interact with API provided by the SafeERC20Upgradeable contract.
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // * --------- CUSTOM EVENTS -----------
    // for transprancy and consistency's sake, we'll emit events for any of the transactions that occur for Users. We make our own events wherever our Base Contracts do not already provide suitable events.
    event EtherDeposited (address depositor, uint256 amount);
    event TKNDeposited (address depositor, uint256 amount);
    event EtherWithdrawn (address withdrawer, uint256 amount);
    event TKNWithdrawn (address withdrawer, uint256 amount);
    // * --------- STATE VARIABLES -----------
    // ---- roles ---
    bytes32 public constant MANAGER = keccak256("MANAGER");
    bytes32 public constant USER = keccak256("USER");
}