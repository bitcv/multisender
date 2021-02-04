const HDWalletProvider = require('@truffle/hdwallet-provider');

const fs = require('fs');
const mnemonic = fs.readFileSync(".secret").toString().trim();

module.exports = {
  networks: {
    testnet: {
      networkCheckTimeout: 100000,
      provider: () => new HDWalletProvider(mnemonic, 'https://http-testnet.hecochain.com'),
      network_id: 256
    },
    mainnet: {
      networkCheckTimeout: 100000,
      provider: () => new HDWalletProvider(mnemonic, 'http://39.105.104.114:8545'),
      network_id: 128
    },
    mynet: {
      networkCheckTimeout: 100000,
      provider: () => new HDWalletProvider(mnemonic, 'http://39.105.104.114:8545'),
      network_id: 128
    }
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    enableTimeouts: false,
    before_timeout: 120000 //
  },

  // Configure your compilers
  compilers: {
    solc: {
       version: "0.4.23",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  },
      //  evmVersion: "byzantium"
      // }
    },
  },
};