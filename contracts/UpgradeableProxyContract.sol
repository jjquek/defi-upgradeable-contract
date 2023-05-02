// contracts/MyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// * --------- OPENZEPELLIN PACKAGES -----------
// A straightforward and robust way to implement upgradeable contracts is to extend contracts provided by OpenZepellin. Their contracts have been the subject of much effort and audit.
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

// * --------- UNISWAP -----------
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

// * --------- LIDO -----------

// * --------- CHAINLINK / PRICE FEEDS -----------

contract UpgradeableProxyContract is
  Initializable,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable
{
  // * --------- ATTACHING LIBRARY FUNCTIONS TO TYPES -----------
  // Need the interface for ERC20Upgradeable to interact with API provided by the SafeERC20Upgradeable library.
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

  // * --------- CUSTOM EVENTS -----------
  // For transprancy and consistency's sake, we'll emit events for any of the transactions that occur for Users. We make our own events wherever our Base Contracts do not already provide suitable events. Note: trade-off is that we spend more gas.
  event EtherDeposited(address depositor, uint256 amount);
  event ERC20Deposited(address depositor, uint256 amount);
  event EtherWithdrawn(address withdrawer, uint256 amount);
  event ERC20Withdrawn(address withdrawer, uint256 amount);

  // * --------- CUSTOM ERROR INSTANCES -----------
  // These are cheaper to revert w as compared to strings.
  error Unauthorized();
  error NothingDeposited();
  error InvalidAssetDeposit();

  // * --------- STATE VARIABLES -----------
  // ---- contract instances ---
  address private constant ROUTER02_ADDRESS =
    0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  IUniswapV2Router02 private router02;
  // ---- roles ---
  bytes32 private constant MANAGER = keccak256("MANAGER");
  bytes32 private constant USER = keccak256("USER");
  // ---- data structures ---
  EnumerableMapUpgradeable.AddressToUintMap private _etherBalances;
  mapping(address => EnumerableMapUpgradeable.AddressToUintMap)
    private _erc20Balances;
  EnumerableSetUpgradeable.AddressSet private _usersWhoDepositedERC20;

  // * --------- INITIALISE / ACCESS CONTROL -----------
  function initialize() public initializer {
    // * we initialise the base contracts as per inheritance requirements, and modify this function with initializer to ensure it is called only once-- like a constructor
    __AccessControl_init();
    // set up various roles
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MANAGER, msg.sender);
    _setRoleAdmin(USER, MANAGER);
    // set up contract instances
    router02 = IUniswapV2Router02(ROUTER02_ADDRESS);
  }

  function assignUserRole(address client) external onlyRole(MANAGER) {
    // * the manager has to make a given address a USER before they can deposit/withdraw.
    if (!hasRole(USER, client)) {
      grantRole(USER, client);
    }
  }

  // * ========== USER FUNCTIONALITY ===========

  // * --------- deposit Ethers functionality -----------
  // * helper function to handle updating the EnumerableMap storing ether balances nicely.
  function updateEthersBalanceWithDeposit(
    address depositor,
    uint256 depositedAmount
  ) internal {
    uint256 newAmount = depositedAmount;
    if (_etherBalances.contains(depositor)) {
      newAmount += _etherBalances.get(depositor); // note: as of 0.8, the Solidity compiler has built-in overflow checking. https://hackernoon.com/hack-solidity-integer-overflow-and-underflow
    }
    _etherBalances.set(depositor, newAmount);
  }

  function depositEther(uint256 amount) external payable onlyRole(USER) {
    require(amount > 0, "depositEther: Deposit amount must be greater than 0");
    updateEthersBalanceWithDeposit(msg.sender, amount);
    emit EtherDeposited(msg.sender, amount);
  }

  function viewDepositedEthersBalance()
    external
    view
    onlyRole(USER)
    returns (uint256 balance)
  {
    // * for users to view their ethers deposited.
    if (_etherBalances.contains(msg.sender)) {
      return _etherBalances.get(msg.sender);
    } else {
      revert NothingDeposited();
    }
  }

  // * --------- withdraw Ethers functionality -----------
  function withdrawEther(uint256 amount) external onlyRole(USER) nonReentrant {
    require(
      amount > 0,
      "withdrawEther: Withdrawal amount must be greater than 0"
    );
    require(
      _etherBalances.get(msg.sender) >= amount,
      "withdrawEther: Insufficient balance"
    );
    // Transfer ETH to the user
    (bool sent, ) = msg.sender.call{ value: amount }(""); // this line makes the function susceptible to reentrancy attacks in the case an attacker becomes a USER. We use the nonReentrant modifier to prevent this. For why transfer() is not used and further reading, see docs. Note: need to consider gas costs that come as a trade-off with using nonReentrant.
    // todo : add to docs about this.
    require(sent, "withdrawEther: Failed to send ETH");
    emit EtherWithdrawn(msg.sender, amount);
    // Update balances
    uint256 newAmount = _etherBalances.get(msg.sender) - amount;
    _etherBalances.set(msg.sender, newAmount);
  }

  // * --------- deposit ERC20 functionality -----------

  // * helper function to handle updating the EnumerableMap storing ERC20 balances nicely.
  function updateERC20BalanceWithDeposit(
    address tokenContractAddress,
    address depositor,
    uint256 depositedAmount
  ) internal {
    uint256 newAmount = depositedAmount;
    // if a key doesn't exist in a solidity mapping, it maps to the default value for that type. The default value of the EnumerableMap.AddressToUintMap is an empty map, so we can check if it exists by checking whether it has items.
    // check if depositor has made a deposit before
    if (_erc20Balances[depositor].length() > 0) {
      // check if depositor is adding to an an existing token balance
      if (_erc20Balances[depositor].contains(tokenContractAddress)) {
        newAmount += _erc20Balances[depositor].get(tokenContractAddress); // note: as of 0.8, the Solidity compiler has built-in overflow checking. https://hackernoon.com/hack-solidity-integer-overflow-and-underflow
      }
    } else {
      // new depositor
      _usersWhoDepositedERC20.add(depositor);
    }
    _erc20Balances[depositor].set(tokenContractAddress, newAmount);
  }

  // * helper function: checks whether a given contract address implements a totalSupply() method as a means of partially validating that a token contract address implements ERC20. Not fullproof as an adversarial contract could easily implement these methods, but we use this as a stopgap measure.
  // * we can devote more time to adding more robusts checks when wanting to go onto mainnet. see docs for more.
  // todo : add links to docs about concerns about ERC20 validation.
  function implementsTotalSupplyMethod(
    address purportedERC20Token
  ) internal view returns (bool result) {
    try IERC20Upgradeable(purportedERC20Token).totalSupply() returns (uint256) {
      return true;
    } catch {
      return false;
    }
  }

  function depositERC20(
    address tokenContractAddress,
    uint256 amount
  ) external onlyRole(USER) {
    require(amount > 0, "depositERC20: Deposit amount must be greater than 0");
    // todo : need more robust check for ERC20 token address validity.
    if (!implementsTotalSupplyMethod(tokenContractAddress)) {
      revert InvalidAssetDeposit();
    }
    SafeERC20Upgradeable.safeTransferFrom(
      IERC20Upgradeable(tokenContractAddress),
      msg.sender,
      address(this),
      amount
    ); // safeTransferFrom throws when token contract returns false.
    emit ERC20Deposited(msg.sender, amount);
    updateERC20BalanceWithDeposit(tokenContractAddress, msg.sender, amount);
    // for why we choose to store the deposits in a private nested mapping variable, see docs.
    // todo : add this in.
  }

  function viewDepositedERC20Balance(
    address addressOfTokenToView
  ) public view onlyRole(USER) returns (uint256) {
    // * for users to view their ethers deposited.
    if (_erc20Balances[msg.sender].length() > 0) {
      return _erc20Balances[msg.sender].get(addressOfTokenToView);
    } else {
      revert NothingDeposited();
    }
  }

  // TODO : implement withdrawERC20 functionality
  // * --------- MANAGER-ONLY FUNCTIONS -----------
  function tradeERC20TokensForUser(
    address tokenIn,
    address tokenOut,
    address userTradingFor,
    uint amountIn,
    uint minAmountOut,
    uint deadline
  ) external onlyRole(MANAGER) {
    // validate tokenIn and tokenOut
    // validate amountIn
    // todo : make deadline conditional
    // approve Router to swap specified amountIn
    // prepare trade path
    // swapExactTokensForTokens
    // update contract state accordingly-- the user's deposited ERC20 token balances should update.
  }

  function stakeEtherOnLidoForUser(
    address userStakingFor,
    uint256 amount
  ) external onlyRole(MANAGER) {
    // todo : implement.
  }

  // * --------- EXTRA STORAGE SPACE -----------
  uint256[50] private __gap; // extra storage space for future upgrade variables- 50 being roughly the space needed for another mapping like _etherBalances for 100 users.
}
