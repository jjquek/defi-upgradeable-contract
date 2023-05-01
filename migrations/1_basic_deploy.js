const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const mockERC20Upgradeable = artifacts.require("mocks/ERC20MockUpgradeable");
const mockERC20AlwaysReturnTrue = artifacts.require(
  "mocks/ERC20ReturnTrueMockUpgradeable"
);
const UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

module.exports = function (deployer) {
  const mockEC20Upgradeable = deployer.deploy(mockERC20Upgradeable);
  const mockAlwaysReturnTrueToken = deployer.deploy(mockERC20AlwaysReturnTrue);
  const proxyInstance = deployProxy(UpgradeableProxyContract, [], {
    deployer,
  });
  console.log("Deployed Proxy's Address:", proxyInstance.address);
};
