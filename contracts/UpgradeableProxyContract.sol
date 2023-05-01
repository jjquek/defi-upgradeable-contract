// contracts/MyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// * --------- OPENZEPELLIN PACKAGES -----------
// A straightforward and robust way to implement upgradeable contracts is to extend contracts provided by OpenZepellin. Their contracts have been the subject of much effort and audit.
// See inline comments where these imports are used for specific reasons.
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract UpgradeableProxyContract is
  Initializable,
  AccessControlUpgradeable,
  ReentrancyGuardUpgradeable
{
  // * --------- ATTACHING LIBRARY FUNCTIONS TO TYPES -----------
  // need the interface for ERC20Upgradeable to interact with API provided by the SafeERC20Upgradeable contract.
  using SafeERC20Upgradeable for IERC20Upgradeable;
  // we use Open-Zeppellin's EnumerableMap to be able to iterate (using 'length' and 'at') over the map-- useful for auditing and also checking balances.
  using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;
  // we use Open-Zeppellin's EnumerableSet to iterate over our nested mapping. (See _usersWhoDepositedERC20)
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

  // * --------- CUSTOM EVENTS -----------
  // for transprancy and consistency's sake, we'll emit events for any of the transactions that occur for Users. We make our own events wherever our Base Contracts do not already provide suitable events. Note: trade-off is that we spend more gas.
  event EtherDeposited(address depositor, uint256 amount);
  event ERC20Deposited(address depositor, uint256 amount);
  event EtherWithdrawn(address withdrawer, uint256 amount);
  event ERC20Withdrawn(address withdrawer, uint256 amount);
  // * --------- CUSTOM ERROR INSTANCES -----------
  // these are cheaper to revert w as compared to strings.
  error Unauthorized();
  error NothingDeposited();
  // * --------- STATE VARIABLES -----------
  // ---- roles ---
  bytes32 private constant MANAGER = keccak256("MANAGER");
  bytes32 private constant USER = keccak256("USER");
  // ---- data structures ---
  EnumerableMapUpgradeable.AddressToUintMap private _etherBalances;
  mapping(address => EnumerableMapUpgradeable.AddressToUintMap)
    private _erc20Balances;
  EnumerableSetUpgradeable.AddressSet private _usersWhoDepositedERC20;

  // while having 2 separate structures makes state logic complicated, this is a workaround for not being able to nest EnumerableMaps.
  // we want a mapping of User : (TokenDeposited : Amount) i.e., we're tracking the amount of tokens deposited for each user, allowing them to deposit different ERC20 tokens. For this, we need a nested mapping.
  // the strategy is that when we need to iterate over the nested mappings, we get the addresses of users who deposited ERC20 from the EnumerableSet, and use this to index the outer mapping of _erc20Balances.
  // the trade-off that comes with this functionality is the need to ensure that both _erc20Balances in _usersWhoDepositedERC20 gets properly updated in deposits and withdrawals.

  // * --------- PUBLIC / EXTERNAL FUNCTIONS -----------
  function initialize() public initializer {
    // we initialise the base contracts as per inheritance requirements, and modify this function with initializer to ensure it is called only once-- like a constructor
    __AccessControl_init();
    // set up various roles
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MANAGER, msg.sender);
    _setRoleAdmin(USER, MANAGER);
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
    if (hasRole(MANAGER, depositor)) {
      revert Unauthorized();
    }
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

  // * --------- withdraw -----------
  // function withdrawEther(uint256 amount) external onlyRole(USER) nonReentrant {
  //   require(
  //     amount > 0,
  //     "withdrawEther: Withdrawal amount must be greater than 0"
  //   );
  //   require(
  //     _etherBalances[msg.sender] >= amount,
  //     "withdrawEther: Insufficient balance"
  //   );

  //   // Update balances
  //   _etherBalances[msg.sender] -= amount;
  //   // Transfer ETH to the user
  //   (bool sent, ) = msg.sender.call{ value: amount }(""); // this line makes the function susceptible to reentrancy attacks in the case an attacker becomes a USER. We use the nonReentrant modifier to prevent this. For why transfer() is not used and further reading, see links appended at the bottom of file. Note: need to consider gas costs that come as a trade-off with using nonReentrant.
  //   require(sent, "withdrawEther: Failed to send ETH");
  //   emit EtherWithdrawn(msg.sender, amount);
  // }

  // function withdrawTKN(
  //   address tokenContractAddress,
  //   uint256 amount
  // ) external onlyRole(USER) nonReentrant {
  //   require(
  //     amount > 0,
  //     "withdrawTKN: Withdrawal amount must be greater than 0"
  //   );
  //   require(
  //     balanceOf(msg.sender) >= amount,
  //     "withdrawTKN: Insufficient balance"
  //   );

  //   // Update balances
  //   _burn(msg.sender, amount);
  //   // Transfer tokens to the user- Note: safeTransfer throws error if transfer doesn't succeed.
  //   SafeERC20Upgradeable.safeTransfer(
  //     IERC20Upgradeable(tokenContractAddress),
  //     msg.sender,
  //     amount
  //   ); // reentrancy vulnerablity is less here compared to in withdrawEther, because fallback functions of an attack contract are not triggered by the safeTransfer call. However, using a transfer function from an external contract we do not control means there is still the possibility of an attack. Note: need to weigh gas costs vs. vulnerability concerns.
  //   emit ERC20Withdrawn(msg.sender, amount);
  // }

  // TODO : implement calculateDollarValue functions.
  // * --------- MANAGER-ONLY FUNCTIONS -----------

  // * --------- EXTRA STORAGE SPACE -----------
  uint256[50] private __gap; // extra storage space for future upgrade variables- 50 being roughly the space needed for another mapping like _etherBalances for 100 users.
}
