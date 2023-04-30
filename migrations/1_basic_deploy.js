const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

module.exports = async function (deployer) {
  // deployment steps
  const instance = await deployProxy(UpgradeableProxyContract, [], {
    deployer,
  });
  console.log("Deployed", instance.address);
};
