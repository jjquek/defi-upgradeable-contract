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

contract UpgradeableProxyContract is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    // need the interface for ERC20Upgradeable to interact with API provided by the SafeERC20Upgradeable contract.
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // * --------- CUSTOM EVENTS -----------
    // for transprancy and consistency's sake, we'll emit events for any of the transactions that occur for Users. We make our own events wherever our Base Contracts do not already provide suitable events.
    event EtherDeposited(address depositor, uint256 amount);
    event TKNDeposited(address depositor, uint256 amount);
    event EtherWithdrawn(address withdrawer, uint256 amount);
    event TKNWithdrawn(address withdrawer, uint256 amount);
    // * --------- STATE VARIABLES -----------
    // ---- roles ---
    bytes32 public constant MANAGER = keccak256("MANAGER");
    bytes32 public constant USER = keccak256("USER");
    // ---- data structures ---
    mapping(address => uint256) private _etherBalances; // _balances from ERC20Upgradeable stores the balance of ERC20 token deposits; this mapping stores the balance of ether deposits

    uint256[50] private __gap; // extra storage space for future upgrade variables- 50 being roughly the space needed for another mapping like _etherBalances for 100 users.

    // * --------- PUBLIC / EXTERNAL FUNCTIONS -----------
    function initialize(address manager) public initializer {
        // we initialise the base contracts as per inheritance requirements, and modify this function with initializer to ensure it is called only once-- like a constructor
        __ERC20_init("My Token", "TKN"); // name and symbol is up to us.
        __AccessControl_init();
        // set up various roles
        _setupRole(DEFAULT_ADMIN_ROLE, manager);
        _setupRole(MANAGER, manager);
        _setRoleAdmin(USER, MANAGER);
    }

    // * --------- deposit -----------
    function depositEther() external payable {
        uint256 amount = msg.value;
        require(
            amount > 0,
            "depositEther: Deposit amount must be greater than 0"
        );
        if (!hasRole(USER, msg.sender)) {
            grantRole(USER, msg.sender);
        }
        _etherBalances[msg.sender] += amount;
        emit EtherDeposited(msg.sender, amount);
    }

    function depositTKN(address tokenContractAddress, uint256 amount) external {
        require(
            amount > 0,
            "depositTKN: Deposit amount must be greater than 0"
        );
        if (!hasRole(USER, msg.sender)) {
            grantRole(USER, msg.sender);
        }
        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(tokenContractAddress),
            msg.sender,
            address(this),
            amount
        );
        _mint(msg.sender, amount);
        emit TKNDeposited(msg.sender, amount);
    }

    // * --------- withdraw -----------
    function withdrawEther(
        uint256 amount
    ) external onlyRole(USER) nonReentrant {
        require(
            amount > 0,
            "withdrawEther: Withdrawal amount must be greater than 0"
        );
        require(
            _etherBalances[msg.sender] >= amount,
            "withdrawEther: Insufficient balance"
        );

        // Update balances
        _etherBalances[msg.sender] -= amount;
        // Transfer ETH to the user
        (bool sent, ) = msg.sender.call{value: amount}(""); // this line makes the function susceptible to reentrancy attacks in the case an attacker becomes a USER. We use the nonReentrant modifier to prevent this. For why transfer() is not used and further reading, see links appended at the bottom of file. Note: need to consider gas costs that come as a trade-off with using nonReentrant.
        require(sent, "withdrawEther: Failed to send ETH");
        emit EtherWithdrawn(msg.sender, amount);
    }

    function withdrawTKN(
        address tokenContractAddress,
        uint256 amount
    ) external onlyRole(USER) nonReentrant {
        require(
            amount > 0,
            "withdrawTKN: Withdrawal amount must be greater than 0"
        );
        require(
            balanceOf(msg.sender) >= amount,
            "withdrawTKN: Insufficient balance"
        );

        // Update balances
        _burn(msg.sender, amount);
        // Transfer tokens to the user- Note: safeTransfer throws error if transfer doesn't succeed.
        SafeERC20Upgradeable.safeTransfer(
            IERC20Upgradeable(tokenContractAddress),
            msg.sender,
            amount
        ); // reentrancy vulnerablity is less here compared to in withdrawEther, because fallback functions of an attack contract are not triggered by the safeTransfer call. However, using a transfer function from an external contract we do not control means there is still the possibility of an attack. Note: need to weigh gas costs vs. vulnerability concerns.
        emit TKNWithdrawn(msg.sender, amount);
    }

    // TODO : implement calculateDollarValue functions.
    // * --------- MANAGER-ONLY FUNCTIONS -----------
}
