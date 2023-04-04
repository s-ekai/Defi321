const Defi321 = artifacts.require("Defi321");
const TokenA = artifacts.require("TokenA");
const TokenB = artifacts.require("TokenB");

module.exports = function(deployer) {
  deployer.deploy(TokenA, 100000).then(() => {
    return deployer.deploy(TokenB, 100000);
  }).then(() => {
    return deployer.deploy(Defi321, TokenA.address);
  });
};