const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

module.exports = async function (deployer) {
  // deployment steps
  const proxyInstance = await deployProxy(UpgradeableProxyContract, [], {
    deployer,
  });
  console.log("Deployed Proxy's Address:", proxyInstance.address);
};
