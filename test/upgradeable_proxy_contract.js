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
  // todo : I want to check whether the address that deploys the contract is set up as the manager.
  /*
   * I think I know the address that deploys it via truffle develop && migrate. Want to verify the difference between Contract Address and Account.
   * I need to check, after that, who provides the manager
   */
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
