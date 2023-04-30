// * --- Mocha API ---
const assert = require("assert");
// * --- OZ Upgrade Plugins ---
const { deployProxy } = require("@openzeppelin/truffle-upgrades");
// * --- Contract Abstractions ---
const UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

contract("UpgradeableProxyContract", function (accounts) {
  let upgradeableProxyContract;

  beforeEach(async () => {
    this.contract = await deployProxy(UpgradeableProxyContract);
  });
  it("should grant the manager who deploys the contract the MANAGER role", async () => {
    const managerAddress = accounts[0]; // 'deploy' or 'migrate' in truffle develop uses the first address as the account address that deploys the contract.
    const isManager = await this.contract.hasRole(
      await this.contract.MANAGER(),
      managerAddress
    );
    assert.equal(
      isManager,
      true,
      "deploying address is not given manager role"
    );
  });
});
