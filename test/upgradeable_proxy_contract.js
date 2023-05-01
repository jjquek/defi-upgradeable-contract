// * --- Chai API ---
const { expect } = require("chai");
// * --- OZ Upgrade Plugins ---
const { deployProxy } = require("@openzeppelin/truffle-upgrades");
// * --- Contract Abstractions ---
const UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

contract("UpgradeableProxyContract", function (accounts) {
  beforeEach(async () => {
    this.proxyContract = await deployProxy(UpgradeableProxyContract);
  });
  it("should grant the manager who deploys the proxyContract the MANAGER role", async () => {
    const managerAddress = accounts[0]; // 'deploy' or 'migrate' in truffle develop uses the first address as the account address that deploys the proxyContract.
    const isManager = await this.proxyContract.hasRole(
      await this.proxyContract.MANAGER(),
      managerAddress
    );
    expect(isManager, "deployer address to be given Manager role").to.be.true;
  });
});
