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
    let managerAddress;
    beforeEach(async () => {
      this.proxyContract = await deployProxy(UpgradeableProxyContract);
      managerAddress = accounts[0];
    });
    it("should grant the manager who deploys the proxyContract the MANAGER role", async () => {
      const managerRoleHash = Web3.utils.soliditySha3("MANAGER");
      // got above code to grab role hash representation from here: https://stackoverflow.com/questions/69647532/checking-and-granting-role-in-solidity
      const isManager = await this.proxyContract.hasRole(
        managerRoleHash,
        managerAddress
      );
      expect(isManager).to.equal(
        true,
        "deployer address should be given MANAGER role"
      );
    });
    it("should allow for the manager to grant an address the USER role", async () => {
      const addressToMakeUser = accounts[1];
      const userRoleHash = Web3.utils.soliditySha3("USER");
      await this.proxyContract.assignUserRole(addressToMakeUser, {
        from: managerAddress,
      });
      const isUser = await this.proxyContract.hasRole(
        userRoleHash,
        addressToMakeUser
      );
      expect(isUser).to.equal(
        true,
        "deployer of contract should be able to make addresses USERs"
      );
    });
  });
  contract("Deposit Ethers Functionality", (accounts) => {
    let managerAddress, userAddress;
    const indexForUserDepositorAddress = 1;
    const indexForNonUserAddress = 2;
    // any address except the first one (reserved for manager, is fine) for the above constants.
    beforeEach(async () => {
      this.proxyContract = await deployProxy(UpgradeableProxyContract);
      managerAddress = accounts[0];
      userAddress = accounts[indexForUserDepositorAddress];
      await this.proxyContract.assignUserRole(userAddress, {
        from: managerAddress,
      });
    });
    it("should not allow non USERs to deposit ether", async () => {});
    // todo : test that only users can call deposit.
    it("should accumulate USER ether deposits correctly", async () => {
      const firstAmount = 10;
      const secondAmount = 10;
      const totalDepositExpected = firstAmount + secondAmount;
      _ = await this.proxyContract.depositEther(firstAmount, {
        from: userAddress,
      });
      _ = await this.proxyContract.depositEther(secondAmount, {
        from: userAddress,
      });
      const depositedAmount =
        await this.proxyContract.viewDepositedEthersBalance({
          from: userAddress,
        });
      expect(depositedAmount.toNumber()).to.equal(
        // note: web3.js uses Big Number objects to represent large numbers outside the range of regular JS numbers. Without toNumber() this will fail.
        totalDepositExpected,
        "deposits should accumulate correctly."
      );
    });
    it("should not allow the MANAGER to deposit ether", async () => {
      await truffleAssert.reverts(
        this.proxyContract.depositEther(10, {
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
      // todo : probably set up a user account here.
    });
    // TODO : add more tests for ERC20 deposit functionality--
    // * additional_test: should be able to deposit two different ERC20 tokens
    // * test: depositing ERC20 should be reflected in the relevant data structures.
  });
  contract.only("Withdraw Ethers Functionality", (accounts) => {
    it("should not allow non-USERs to withdraw ethers deposited.", async () => {
      // todo
    });
    it("should allow USERs to withdraw ethers they deposited", async () => {
      // todo
    });
    it("should emit an EtherWithdrawn event.", async () => {
      // todo
    });
  });
});
