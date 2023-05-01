// * --- Chai API ---
const { expect } = require("chai");
// * --- OZ Upgrade Plugins ---
const { deployProxy } = require("@openzeppelin/truffle-upgrades");
// * --- Web3 API - for Role checking ---
const Web3 = require("web3");
// * --- Truffle Assertions Library ---
// makes it easier to check that functions revert; useful for testing w Open-Zepp contracts. see: https://ethereum.stackexchange.com/questions/48627/how-to-catch-revert-error-in-truffle-test-javascript
const truffleAssert = require("truffle-assertions");
// * --- Contract Abstractions ---
const UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

describe("UpgradeableProxyContract", () => {
  // 'contract' works like 'describe' in Mocha, but provides truffle's "clean-room features", including the accounts made available by truffle develop. See https://trufflesuite.com/docs/truffle/how-to/debug-test/write-tests-in-javascript/#use-contract-instead-of-describe for more.
  contract("Contract Creation", (accounts) => {
    it("should grant the manager who deploys the proxyContract the MANAGER role", async () => {
      const proxyContract = await deployProxy(UpgradeableProxyContract);
      const managerAddress = accounts[0]; // 'deploy' or 'migrate' in truffle develop uses the first address as the account address that deploys the proxyContract.
      const managerRoleHash = Web3.utils.soliditySha3("MANAGER");
      // got above code to grab role hash representation from here: https://stackoverflow.com/questions/69647532/checking-and-granting-role-in-solidity
      const isManager = await proxyContract.hasRole(
        managerRoleHash,
        managerAddress
      );
      expect(isManager).to.equal(
        true,
        "deployer address should be given MANAGER role"
      );
    });
  });
  contract("Deposit Functionality", (accounts) => {
    let managerAddress;
    const indexForEtherDepositorAddress = 1;
    const indexForERC20DepositorAddress = 2;
    // any address except the first one (reserved for manager, is fine) for the above constants.
    beforeEach(async () => {
      this.proxyContract = await deployProxy(UpgradeableProxyContract);
      managerAddress = accounts[0];
    });
    it("ETHER: should make anyone who deposits ether into a USER", async () => {
      const depositor = accounts[indexForEtherDepositorAddress];
      const amount = 20;
      _ = await this.proxyContract.depositEther(depositor, amount, {
        from: managerAddress,
      });
      const userRoleHash = Web3.utils.soliditySha3("USER");
      const isUser = await this.proxyContract.hasRole(userRoleHash, depositor);
      expect(isUser).to.equal(
        true,
        "address who deposits ether should be made a USER"
      );
    });
    it("ETHER: should accumulate USER ether deposits correctly", async () => {
      const depositor = accounts[indexForEtherDepositorAddress];
      const firstAmount = 10;
      const secondAmount = 10;
      const totalDepositExpected = firstAmount + secondAmount;
      _ = await this.proxyContract.depositEther(depositor, firstAmount, {
        from: managerAddress,
      });
      _ = await this.proxyContract.depositEther(depositor, secondAmount, {
        from: managerAddress,
      });
      const depositedAmount = await this.proxyContract.viewEthersBalance({
        from: depositor,
      });
      expect(depositedAmount.toNumber()).to.equal(
        // note: web3.js uses Big Number objects to represent large numbers outside the range of regular JS numbers. Without toNumber() this will fail.
        totalDepositExpected,
        "deposits should accumulate correctly."
      );
    });
    it("ETHER: should not allow the MANAGER to deposit ether", async () => {
      await truffleAssert.reverts(
        this.proxyContract.depositEther(managerAddress, 10, {
          from: managerAddress,
        })
      );
    });
  });
  // should allow a User to deposit ether
  // should allow a User to deposit ERC20 tokens
  // should allow a user to withdraw ether they deposited
  // should not allow a user to withdraw more than they deposited.
  // should not allow the Manager to withdraw ether
  // should not allow the Manager to withdraw ERC20 tokens
  // should not allow the Manager to deposit ether
  // should not allow the Manager to deposit ERC20 tokens
  // only Users should be able to withdraw Ether
  // only Users should be able to withdraw ERC20 tokens
});
