let UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

module.exports = function (deployer) {
  // deployment steps
  deployer.deploy(UpgradeableProxyContract);
  console.log("Great Success");
};
