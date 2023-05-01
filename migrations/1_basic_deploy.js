const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const mockERC20 = artifacts.require("ERC20ReturnTrueMockUpgradeable");
const UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

module.exports = async function (deployer) {
  // deployment steps
  const mockTokenInstance = await deployer.deploy(mockERC20);
  const proxyInstance = await deployProxy(UpgradeableProxyContract, [], {
    deployer,
  });
  console.log("Deployed Proxy's Address:", proxyInstance.address);
};
