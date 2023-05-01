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
const MockAlwaysReturnTrueERC20 = artifacts.require(
  "ERC20ReturnTrueMockUpgradeable"
);
// todo : require the ERC20MockUpgradeable artifact when testing involves two distinct mock ERC20 tokens.
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
  contract("Deposit Ethers Functionality", (accounts) => {
    let managerAddress;
    const indexForEtherDepositorAddress = 1;
    // any address except the first one (reserved for manager, is fine) for the above constants.
    beforeEach(async () => {
      this.proxyContract = await deployProxy(UpgradeableProxyContract);
      managerAddress = accounts[0];
    });
    it("should make anyone who deposits ether into the contract a USER", async () => {
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
    it("should accumulate USER ether deposits correctly", async () => {
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
      const depositedAmount =
        await this.proxyContract.viewDepositedEthersBalance({
          from: depositor,
        });
      expect(depositedAmount.toNumber()).to.equal(
        // note: web3.js uses Big Number objects to represent large numbers outside the range of regular JS numbers. Without toNumber() this will fail.
        totalDepositExpected,
        "deposits should accumulate correctly."
      );
    });
    it("should not allow the MANAGER to deposit ether", async () => {
      await truffleAssert.reverts(
        this.proxyContract.depositEther(managerAddress, 10, {
          from: managerAddress,
        })
      );
    });
  });
  contract("Deposit ERC20 Functionality", (accounts) => {
    let managerAddress;
    const indexForERC20DepositorAddress = 1;
    // any address except the first one (reserved for manager, is fine) for the above constants.
    beforeEach(async () => {
      this.proxyContract = await deployProxy(UpgradeableProxyContract);
      managerAddress = accounts[0];
      this.mockERC20Contract = await MockAlwaysReturnTrueERC20.deployed();
    });
    it("should make anyone who deposits ERC20 into the contract a USER", async () => {
      const depositor = accounts[indexForERC20DepositorAddress];
      const amount = 20;
      _ = await this.proxyContract.depositERC20(
        this.mockERC20Contract.address,
        depositor,
        amount,
        {
          from: managerAddress,
        }
      );
      const userRoleHash = Web3.utils.soliditySha3("USER");
      const isUser = await this.proxyContract.hasRole(userRoleHash, depositor);
      expect(isUser).to.equal(
        true,
        "address who deposits ERC20 should be made a USER"
      );
    });
    // TODO : add more tests for ERC20 deposit functionality--
    // * additional_test: should be able to deposit two different ERC20 tokens
    // * test: manager should not be allowed to deposit ERC20
    // * test: depositing ERC20 should be reflected in the relevant data structures.
  });
});
