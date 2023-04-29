const UpgradeableProxyContract = artifacts.require("UpgradeableProxyContract");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */
contract("UpgradeableProxyContract", function (/* accounts */) {
  it("should assert true", async function () {
    await UpgradeableProxyContract.deployed();
    return assert.isTrue(true);
  });
});
