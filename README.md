<div style="width: 100%;">
  <img src="banner.svg" style="width: 100%;" alt="banner">
</div>

# 🎲 PVPBet

[![npm version](https://img.shields.io/npm/v/@pvpbet/pvpbet/latest.svg)](https://www.npmjs.com/package/@pvpbet/pvpbet)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Tests](https://github.com/pvpbet/pvpbet/actions/workflows/tests.yml/badge.svg)](https://github.com/pvpbet/pvpbet/actions/workflows/tests.yml)

A decentralized PVP betting platform based on the Ethereum Virtual Machine ([EVM](https://ethereum.org/zh/developers/docs/evm)).

## 👋 Introduction

PVPBet is a decentralized betting platform leveraging Web3 technology to ensure fairness and transparency in wagering.

Traditional betting often suffers from trust issues, especially in the enforcement of bets. PVPBet addresses this by using smart contracts to handle funds and determine winners based on community voting, powered by governance token holders.

These token holders are incentivized to vote fairly, as their long-term stakes in the platform align their interests with its integrity.

Additionally, users can participate in the entire betting process—from wagering and deciding to disputing and arbitrating—without needing to connect their wallets. This is done through direct transfers, eliminating concerns over wallet security.

Through this decentralized approach, PVPBet provides a secure, reliable, and transparent environment for users to engage in player-versus-player betting.

## 📖 Documentation

For detailed documentation, please visit [docs.pvpbet.xyz](https://docs.pvpbet.xyz/).

## 🛠️ Technology Stack

Our project leverages a range of technologies to ensure robust smart contract development, testing, and deployment. Below is a detailed list of the technology stack we use:

- [**Solidity**](https://soliditylang.org/): The primary programming language for writing our smart contracts. Solidity is a statically-typed programming language designed for developing smart contracts that run on the Ethereum Virtual Machine (EVM).

- [**OpenZeppelin**](https://openzeppelin.com/contracts/): A library for secure smart contract development. OpenZeppelin Contracts is a library of modular, reusable, secure smart contracts, written in Solidity. It's an open-source framework for the Ethereum community.

- [**Hardhat**](https://hardhat.org/): A development environment to compile, deploy, test, and debug Ethereum software. Hardhat is designed to help developers manage and automate the recurring tasks inherent to the process of building smart contracts and dApps.

- [**Viem**](https://viem.sh/): A TypeScript Interface for Ethereum that provides low-level stateless primitives for interacting with Ethereum. An alternative to `ethers.js` and `web3.js` with a focus on reliability, efficiency, and excellent developer experience.

- [**Chai**](https://www.chaijs.com/): An assertion library for node and the browser that can be delightfully paired with any javascript testing framework. Chai is often used as the testing framework for writing tests for Ethereum smart contracts.

This technology stack provides us with the tools necessary to ensure our smart contracts are secure, reliable, and efficient. We encourage contributors to familiarize themselves with these technologies to better understand our development and testing processes.

## 🔍 Running Tests

To ensure the reliability and security of our smart contracts, we have implemented comprehensive test suites using the Chai testing framework. Follow the steps below to run the tests and verify the contracts' functionalities.

Before running the tests, make sure you have the following installed:
- Node.js (recommend using the latest stable version)
- npm (Node.js package manager)

```shell
npm install
npm run test
```

After running the tests, you'll see output in the terminal indicating whether each test has passed or failed.

## Licensing

See [LICENSE](LICENSE).

