// contracts/MyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// * --------- OPENZEPELLIN PACKAGES -----------
// A straightforward and robust way to implement upgradeable contracts is to extend contracts provided by OpenZepellin. Using their upgrade plugins, we don't have to create separate Proxy and Implementation contracts ourselves. More generally, their contracts/utilities have been the subject of much effort and audit.
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
interface ILido {
  // we add the functions we need to call on Lido here
  function getTotalShares() external returns (uint256);

  function getTotalPooledEther() external returns (uint256);

  function submit() external payable returns (uint256);

  function transfer(
    address _recipient,
    uint256 _amount
  ) external returns (bool);
}

// Contract w API for effective math calculations; relevant for staking.
import "./ABKDMathQuad.sol";

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
  address private constant ROUTER02_GOERLI_TESTNET_ADDRESS =
    0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  IUniswapV2Router02 private _router02;
  EnumerableMapUpgradeable.AddressToUintMap private _router02ERC20Allowances;
  address private constant LIDO_GOERLI_TESTNET_ADDRESS =
    0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
  ILido private _lido;
  address private constant LIDO_stETH_GOERLI_TESTNET_ADDRESS =
    0x1643E812aE58766192Cf7D2Cf9567dF2C37e9B7F;
  // ---- roles ---
  bytes32 private constant MANAGER = keccak256("MANAGER");
  bytes32 private constant USER = keccak256("USER");
  // ---- data structures ---
  EnumerableMapUpgradeable.AddressToUintMap private _etherBalances;
  mapping(address => EnumerableMapUpgradeable.AddressToUintMap)
    private _erc20Balances;
  EnumerableSetUpgradeable.AddressSet private _usersWhoDepositedERC20;

  // todo : explain why _usersWhoDepositedERC20 is here.

  // * --------- INITIALISE / ACCESS CONTROL -----------
  function initialize() public initializer {
    // * we initialise the base contracts as per inheritance requirements, and modify this function with initializer to ensure it is called only once-- like a constructor
    __AccessControl_init();
    // set up various roles
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _setupRole(MANAGER, msg.sender);
    _setRoleAdmin(USER, MANAGER);
    // set up contract instances
    _router02 = IUniswapV2Router02(ROUTER02_GOERLI_TESTNET_ADDRESS);
    _lido = ILido(LIDO_GOERLI_TESTNET_ADDRESS);
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
    // todo : remove user's record from balances if withdrawal has zeroed deposits.
    // todo : and remove User privileges if so.
    // todo : probably emit Event that user has been removed.
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

  function depositERC20(
    address tokenContractAddress,
    address userAddress,
    uint256 amount
  ) external onlyRole(MANAGER) {
    require(amount > 0, "depositERC20: Deposit amount must be greater than 0");
    // note: ERC20 deposits are handled differently from ether deposits-- ERC20 deposits are called by the MANAGER whereas USERs can deposit ethers into the contract directly. This is due to the difficulty of having a robust way of validating that a given address is really an ERC20 token. Despite this displacing control from the USER to the MANAGER, the security of the contract is worth this additional restriction. todo : see docs for more.
    if (!hasRole(USER, userAddress)) {
      revert Unauthorized();
    }
    SafeERC20Upgradeable.safeTransferFrom(
      IERC20Upgradeable(tokenContractAddress),
      userAddress,
      address(this),
      amount
    ); // safeTransferFrom throws when token contract returns false.
    emit ERC20Deposited(userAddress, amount);
    updateERC20BalanceWithDeposit(tokenContractAddress, userAddress, amount);
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

  // * helper function to handle updating the EnumerableMap storing ERC20 balances nicely.
  function updateERC20BalanceWithWithdrawal(
    address tokenContractAddress,
    address withdrawer,
    uint256 amountToWithdraw
  ) internal {
    uint256 newAmount = amountToWithdraw;
    // very similar logic to updateERC20BalanceWithDeposit
    if (_erc20Balances[withdrawer].length() > 0) {
      if (_erc20Balances[withdrawer].contains(tokenContractAddress)) {
        newAmount -= _erc20Balances[withdrawer].get(tokenContractAddress); // note: as of 0.8, the Solidity compiler has built-in overflow checking. https://hackernoon.com/hack-solidity-integer-overflow-and-underflow
      } else {
        revert("withdrawing token that hasn't been deposited");
      }
    } else {
      revert("withdrawing even though no tokens deposited");
    }
    // update the mapping with a new key:value pair
    _erc20Balances[withdrawer].set(tokenContractAddress, newAmount);
    // todo : remove record if withdrawal has zeroed user's deposits.
    // todo : remove User role
    // todo : probably emit Event that user has been removed.
  }

  function withdrawDepositedERC20Token(
    address addressOfTokenToWithdraw,
    uint256 amountToWithdraw
  ) external onlyRole(USER) {
    // validate inputs
    require(
      amountToWithdraw > 0,
      "withdrawERC20: Withdrawal amount must be greater than 0"
    );
    require(
      viewDepositedERC20Balance(addressOfTokenToWithdraw) >= amountToWithdraw,
      "withdrawERC20: Withdrawal amount must be less than or equal to deposited amount."
    );
    // transfer the Token to the User
    SafeERC20Upgradeable.safeTransferFrom(
      IERC20Upgradeable(addressOfTokenToWithdraw),
      address(this),
      msg.sender,
      amountToWithdraw
    ); // safeTransferFrom throws when token contract returns false.
    // emit relevant event.
    emit ERC20Withdrawn(msg.sender, amountToWithdraw);
    // update the balances
    updateERC20BalanceWithWithdrawal(
      addressOfTokenToWithdraw,
      msg.sender,
      amountToWithdraw
    );
  }

  // * --------- MANAGER-ONLY FUNCTIONS -----------

  // * helper function to handle updating the EnumerableMap storing ERC20 balances nicely.
  function updateERC20BalanceWithSwap(
    address tokenTraded,
    address tokenFromTrade,
    address userTradedFor,
    uint amountForTrade,
    uint amountFromTrade
  ) internal onlyRole(MANAGER) {
    if (_erc20Balances[userTradedFor].length() > 0) {
      // user who deposited tokens
      if (_erc20Balances[userTradedFor].contains(tokenTraded)) {
        // user had deposited token that was traded
        uint newAmount = _erc20Balances[userTradedFor].get(tokenTraded) -
          amountForTrade; // 0.8 solidity compiler reverts on underflow
        // todo : remove record if newAmount is zero
        _erc20Balances[userTradedFor].set(tokenTraded, newAmount);
      } else {
        revert("swapped token for user that wasn't deposited");
      }
    } else {
      revert("swapped tokens for user that did not deposit");
    }
    updateERC20BalanceWithDeposit(
      tokenFromTrade,
      userTradedFor,
      amountFromTrade
    );
  }

  function tradeERC20TokensForUser(
    address tokenIn,
    address tokenOut,
    address userTradingFor,
    uint amountIn,
    uint minAmountOut,
    uint deadline
  ) external onlyRole(MANAGER) {
    // * validate inputs
    require(tokenIn != tokenOut, "tokens to swap must be different");
    require(amountIn > 0 && minAmountOut > 0, "invalid amounts for token swap");
    require(
      hasRole(USER, userTradingFor),
      "token swapped must be done for a USER"
    );
    // setting default value for deadline if none is provided
    if (deadline <= 0) {
      deadline = block.timestamp + 60; // 60s/1min from current block.timestamp
    }
    // * approving router to swap amountIn of tokenIn
    // note: vanilla ERC20 approve methods are known to have issues w race conditions and security. see https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729 and https://docs.openzeppelin.com/contracts/2.x/api/token/erc20#IERC20-approve-address-uint256-. Open-Zepp's recommendation is that safeApprove is used only for setting an initial allowance, and the other helpers for adjusting it.
    if (_router02ERC20Allowances.contains(tokenIn)) {
      // there's an existing allowance for tokenIn
      if (_router02ERC20Allowances.get(tokenIn) < amountIn) {
        // but it needs to increased for amountIn
        SafeERC20Upgradeable.safeIncreaseAllowance(
          IERC20Upgradeable(tokenIn),
          address(_router02),
          amountIn
        );
        _router02ERC20Allowances.set(tokenIn, amountIn);
      }
    } else {
      // there's no existing allowance for tokenIn
      SafeERC20Upgradeable.safeApprove(
        IERC20Upgradeable(tokenIn),
        address(_router02),
        amountIn
      );
      _router02ERC20Allowances.set(tokenIn, amountIn);
    }
    // * prepare trade path
    address[] memory path = new address[](2);
    path[0] = tokenIn;
    path[1] = tokenOut;
    // * execute trade
    uint[] memory inputAndOutputTokenAmounts = _router02
      .swapExactTokensForTokens(
        amountIn,
        minAmountOut,
        path,
        address(this),
        deadline
      ); // tokens out are deposited into contract if trade is successful
    // * update user's token balances
    updateERC20BalanceWithSwap(
      tokenIn,
      tokenOut,
      userTradingFor,
      inputAndOutputTokenAmounts[0], // input token amount
      inputAndOutputTokenAmounts[1] // output token amount
    );
  }

  function stakeEtherOnLidoForUser(
    address userStakingFor,
    uint256 amount
  ) external onlyRole(MANAGER) {
    // * validate inputs
    require(amount > 0, "eth amount staked must be greater than 0");
    require(hasRole(USER, userStakingFor), "address is not a user");
    require(
      _etherBalances.contains(userStakingFor),
      "user hasn't deposited any ether"
    );
    require(
      _etherBalances.get(userStakingFor) >= amount,
      "user doesn't have enough ether for stake amount"
    );
    // * stake ether for stEth
    // the amount of stEth one has from staking a certain amount of ether needs to be calculated from the amount stEth shares generated. 'stEth' and 'stEth shares' are not equivalent.
    uint256 amountOfstETHShares = ILido(LIDO_GOERLI_TESTNET_ADDRESS).submit{
      value: amount
    }();
    uint256 newAmount = _etherBalances.get(userStakingFor) - amount;
    // todo : handle zeroed case.
    _etherBalances.set(userStakingFor, newAmount);
    // formula: balanceOf(account) = shares[account] * totalPooledEther / totalShares
    // from and explained here: https://docs.lido.fi/contracts/lido#rebasing
    // we use ABKDMath.Quad to handle multiplication and division to avoid complications with division in Solidity (e.g. rounding to zero)
    uint256 amountOfstEth = ABDKMathQuad.toUInt(
      ABDKMathQuad.div(
        ABDKMathQuad.mul(
          ABDKMathQuad.fromUInt(amountOfstETHShares),
          ABDKMathQuad.fromUInt(
            ILido(LIDO_GOERLI_TESTNET_ADDRESS).getTotalPooledEther()
          )
        ),
        ABDKMathQuad.fromUInt(
          ILido(LIDO_GOERLI_TESTNET_ADDRESS).getTotalShares()
        )
      )
    );
    // * transfer amount of stEth generated into contract as well as update mappings.
    require(
      ILido(LIDO_GOERLI_TESTNET_ADDRESS).transfer(address(this), amountOfstEth),
      "failed to transfer stEth to contract"
    );
    updateERC20BalanceWithDeposit(
      LIDO_stETH_GOERLI_TESTNET_ADDRESS,
      userStakingFor,
      amountOfstEth
    );
  }

  // * --------- EXTRA STORAGE SPACE -----------
  uint256[50] private __gap; // extra storage space for future upgrade variables- 50 being roughly the space needed for another mapping like _etherBalances for 100 users.
}
