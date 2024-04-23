require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        },
      }
    ]
  },
  networks: {
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.SEPOLIA_API_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: "",
      }
    },
    goerli: {
      url: `https://eth-goerli.g.alchemy.com/v2/${process.env.GOERLI_API_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: "",
      }
      // gasPrice: 10000000,
      // gas: 10000000
    },
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.POLYGON_API_KEY}`,
      accounts: {
        mnemonic: process.env.MNEMONIC,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20,
        passphrase: "",
      },
      gasPrice: 150_000_000_000,
      gas: 10_000_000
    },
    hardhat: {
      forking: {
        url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.SEPOLIA_API_KEY}`, // fork Sepolia
        blockNumber: 4622899, // Sepolia blocknum
        // url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.POLYGON_API_KEY}`, // fork Polygon
        // blockNumber: 42781941, // Polygon blocknum
        // url: `https://eth-goerli.g.alchemy.com/v2/${process.env.GOERLI_API_KEY}`, // fork Goerli
        // blockNumber: 8818536, // Goerli blocknum
        // url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.MAINNET_API_KEY}`, // fork Mainnet
        // blockNumber: 16728000 // Mainnet blocknum
        accounts: {
          mnemonic: process.env.MNEMONIC,
          path: "m/44'/60'/0'/0",
          initialIndex: 0,
          count: 20,
          passphrase: "",
        }
        // gasPrice: "10000000",
        // gas: "10000000"
      },
      allowUnlimitedContractSize: false,
    }
  }
};
