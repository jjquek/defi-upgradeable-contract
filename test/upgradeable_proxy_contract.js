// * --- Chai API ---
const { expect } = require("chai");
// * --- OZ Upgrade Plugins ---
const { deployProxy } = require("@openzeppelin/truffle-upgrades");
// * --- Web3 API - for Role checking ---
const Web3 = require("web3");
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
    it("should make anyone who deposits ether into a USER", async () => {
      const addressWhoDepositsEther = accounts[indexForEtherDepositorAddress];
      const amount = 20;
      const result = await this.proxyContract.depositEther(
        addressWhoDepositsEther,
        amount,
        { from: managerAddress }
      );
      const userRoleHash = Web3.utils.soliditySha3("USER");
      const isUser = await this.proxyContract.hasRole(
        userRoleHash,
        addressWhoDepositsEther
      );
      expect(isUser).to.equal(
        true,
        "address who deposits ether should be made a USER"
      );
    });
    // it("should allow USERs to deposit more ether", async () => {});
    // it("should not allow the MANAGER to deposit ether", async () => {});
    // it("should not allow negative amounts to be deposited", async () => {});
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
