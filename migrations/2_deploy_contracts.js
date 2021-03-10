var DAO = artifacts.require("DAO");

module.exports = function(deployer) {
  deployer.deploy(DAO,3600,3600,55);
};
