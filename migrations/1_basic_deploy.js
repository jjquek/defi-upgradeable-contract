const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const mockERC20Upgradeable = artifacts.require("mocks/ERC20MockUpgradeable");
const mockERC20AlwaysReturnTrue = artifacts.require(
  "mocks/ERC20ReturnTrueMockUpgradeable"
);
const UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

module.exports = async function (deployer) {
  // deployment steps
  const mockEC20Upgradeable = await deployer.deploy(mockERC20Upgradeable);
  const mockAlwaysReturnTrueToken = await deployer.deploy(
    mockERC20AlwaysReturnTrue
  );
  const proxyInstance = await deployProxy(UpgradeableProxyContract, [], {
    deployer,
  });
  console.log("Deployed Proxy's Address:", proxyInstance.address);
};
