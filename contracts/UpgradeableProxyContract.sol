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

  // * --------- PUBLIC / EXTERNAL FUNCTIONS -----------
  function initialize() public initializer {
    // we initialise the base contracts as per inheritance requirements, and modify this function with initializer to ensure it is called only once-- like a constructor
    __AccessControl_init();
    // set up various roles
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MANAGER, msg.sender);
    _setRoleAdmin(USER, MANAGER);
    // set up contract instances
    router02 = IUniswapV2Router02(ROUTER02_ADDRESS);
  }

  // * --------- deposit -----------
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

  function depositEther(address depositor, uint256 amount) external payable {
    // note: we want the MANAGER address to be invoking this function as they are the role admin for USERs in the contract. Thus, we make the depositor and amount parameters so that 'msg.sender' is the MANAGER and thus can invoke the access control functions.
    if (hasRole(MANAGER, depositor)) {
      revert Unauthorized();
    }
    require(amount > 0, "depositEther: Deposit amount must be greater than 0");
    if (!hasRole(USER, depositor)) {
      grantRole(USER, depositor);
    }
    updateEthersBalanceWithDeposit(depositor, amount);
    emit EtherDeposited(depositor, amount);
  }

  function viewDepositedEthersBalance()
    external
    view
    returns (uint256 balance)
  {
    // * for users to view their ethers deposited.
    if (_etherBalances.contains(msg.sender)) {
      return _etherBalances.get(msg.sender);
    } else {
      revert NothingDeposited();
    }
  }

  // TODO : test more for the depositing ERC20 logic.
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

  function depositERC20(
    address tokenContractAddress,
    address depositor,
    uint256 amount
  ) external {
    require(amount > 0, "depositERC20: Deposit amount must be greater than 0");
    SafeERC20Upgradeable.safeTransferFrom(
      IERC20Upgradeable(tokenContractAddress),
      depositor,
      address(this),
      amount
    ); // safeTransferFrom throws on failure.
    emit ERC20Deposited(depositor, amount);
    if (!hasRole(USER, depositor)) {
      grantRole(USER, depositor);
    }
    updateERC20BalanceWithDeposit(tokenContractAddress, depositor, amount);
  }

  function viewDepositedERC20Balance(
    address addressOfTokenToView
  ) external view returns (uint256) {
    // * for users to view their ethers deposited.
    if (_erc20Balances[msg.sender].length() > 0) {
      return _erc20Balances[msg.sender].get(addressOfTokenToView);
    } else {
      revert NothingDeposited();
    }
  }

  // TODO : implement withdraw functionality
  // * --------- withdraw -----------

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
