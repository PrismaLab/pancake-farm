// Contracts are compiled without optimization
// and with gas estimation distortion
// https://github.com/sc-forks/solidity-coverage/blob/master/HARDHAT_README.md#usage

module.exports = {
    // Skip third-party code and standard token implementation.
  skipFiles: [
    "libs",
    "testlibs",
    "utils",
    "PAPAToken.sol",
    "YAYAToken.sol",
  ],
  measureStatementCoverage: true,
  measureFunctionCoverage: true,
};
