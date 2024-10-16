import type { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-ignition-viem'
import '@nomicfoundation/hardhat-ledger'
import '@nomicfoundation/hardhat-toolbox-viem'
import '@nomicfoundation/hardhat-verify'
import '@openzeppelin/hardhat-upgrades'
import 'hardhat-gas-reporter'
import 'dotenv/config'
import {
  base,
  baseSepolia,
} from 'viem/chains'
import type { Chain } from 'viem'
import fs from 'node:fs'

const chains: Record<string, Chain> = {
  base,
  baseSepolia,
}

let networks: Record<string, Record<string, string>> = {}
try {
  networks = JSON.parse(fs.readFileSync('./networks.json', 'utf8'))
} catch {
  // ignore
}

const accounts = [
  process.env.WALLET_PRIVATE_KEY as string,
].filter(Boolean)
const ledgerAccounts = [
  process.env.WALLET_LEDGER_ACCOUNT as string,
].filter(Boolean)

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS === 'true',
    L2: 'arbitrum',
    excludeContracts: [
      'AttackContract',
      'DAI',
      'TestBet',
      'TestBetManager',
      'TestBetOption',
      'USDC',
    ],
  },
  etherscan: {
    apiKey: Object.keys(networks).reduce((acc: Record<string, string>, key) => {
      acc[key] = networks[key].apiKey
      return acc
    }, {}),
    customChains: Object.keys(networks)
      .map((key: string) => {
        const chain: Chain = chains[key]
        if (chain) {
          return {
            network: key,
            chainId: chain.id,
            urls: {
              apiURL: chain.blockExplorers?.default?.apiUrl,
              browserURL: chain.blockExplorers?.default?.url,
            },
          }
        } else {
          return null
        }
      })
      .filter(Boolean) as [],
  },
  sourcify: {
    enabled: true,
  },
  networks: Object.fromEntries(
    Object.keys(networks)
      .map((key: string) => {
        const chain: Chain = chains[key]
        if (chain) {
          return [
            key,
            {
              chainId: chain.id,
              url: networks[key].rpc || chain.rpcUrls.default.http[0],
              accounts,
              ledgerAccounts,
            },
          ]
        } else {
          return null
        }
      })
      .filter(Boolean) as [],
  ),
}

export default config
