// SPDX-License-Identifier: MIT

// yanked this code from: https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/master/contracts/mocks/token/ERC20ReturnTrueMockUpgradeable.sol ; unsure why it wasn't included in the installed contracts-upgradeable dependency.
// just need this Mock for testing purposes.
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ERC20ReturnTrueMockUpgradeable is Initializable {
  function __ERC20ReturnTrueMock_init() internal onlyInitializing {}

  function __ERC20ReturnTrueMock_init_unchained() internal onlyInitializing {}

  mapping(address => uint256) private _allowances;

  function transfer(address, uint256) public pure returns (bool) {
    return true;
  }

  function transferFrom(address, address, uint256) public pure returns (bool) {
    return true;
  }

  function approve(address, uint256) public pure returns (bool) {
    return true;
  }

  function setAllowance(address account, uint256 allowance_) public {
    _allowances[account] = allowance_;
  }

  function allowance(address owner, address) public view returns (uint256) {
    return _allowances[owner];
  }

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[49] private __gap;
}
