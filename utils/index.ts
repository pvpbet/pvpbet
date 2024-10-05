import { readFile, writeFile } from 'fs/promises'
import { viem, ethers, upgrades } from 'hardhat'
import {
  createWalletClient,
  erc20Abi,
  http,
  getAddress,
  getContract,
  isAddressEqual,
  zeroAddress,
} from 'viem'
import type {
  Address,
  ContractFunctionName,
  ContractFunctionArgs,
  Hash,
} from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { hardhat } from 'viem/chains'
import type { DeployProxyOptions } from '@openzeppelin/hardhat-upgrades/src/utils'
import type {
  PublicClient,
  WalletClient,
} from '@nomicfoundation/hardhat-viem/types'

type Erc20FunctionName = ContractFunctionName<typeof erc20Abi, 'pure' | 'view'>
type Erc20Args = ContractFunctionArgs<typeof erc20Abi, 'pure' | 'view', Erc20FunctionName>

export async function deployProxy(contractName: string, args: unknown[], options: DeployProxyOptions) {
  const contract = await upgrades.deployProxy(
    await ethers.getContractFactory(contractName),
    args,
    options,
  )
  return viem.getContractAt(
    contractName,
    getAddress(contract.target as string),
  )
}

export async function upgradeProxy(contractAddress: string, newContractName: string) {
  const patch = await ethers.getContractFactory(newContractName)
  return upgrades.upgradeProxy(contractAddress, patch)
}

export async function deployContract(
  owner: WalletClient,
  abi: unknown[],
  bytecode: string,
  args?: unknown[],
) {
  const publicClient = (await viem.getPublicClient()) as PublicClient
  const hash = await owner.deployContract({
    abi,
    bytecode: bytecode as `0x${string}`,
    args,
  })
  const receipt = await publicClient.waitForTransactionReceipt({ hash })
  return getContract({
    address: receipt.contractAddress as Address,
    abi,
    client: publicClient,
  })
}

export async function erc20Read(
  token: Address,
  functionName: Erc20FunctionName,
  args?: Erc20Args,
) {
  const publicClient = (await viem.getPublicClient()) as PublicClient
  return publicClient.readContract({
    address: token,
    abi: erc20Abi,
    functionName,
    args,
  })
}

export async function erc20Approve(
  owner: WalletClient,
  token: Address,
  spender: Address,
  amount: bigint,
) {
  return owner.writeContract({
    address: token,
    abi: erc20Abi,
    functionName: 'approve',
    args: [spender, amount],
  })
}

export async function erc20Transfer(
  owner: WalletClient,
  token: Address,
  to: Address,
  amount: bigint,
) {
  return owner.writeContract({
    address: token,
    abi: erc20Abi,
    functionName: 'transfer',
    args: [to, amount],
  })
}

export async function transfer(
  owner: WalletClient,
  token: Address,
  to: Address,
  amount: bigint,
) {
  if (isAddressEqual(token, zeroAddress)) {
    return owner.sendTransaction({ to, value: amount })
  } else {
    return erc20Transfer(owner, token, to, amount)
  }
}

export async function getBalance(
  token: Address,
  owner: Address,
) {
  const publicClient = (await viem.getPublicClient()) as PublicClient
  if (isAddressEqual(zeroAddress, token)) {
    return publicClient.getBalance({ address: owner })
  } else {
    return erc20Read(token, 'balanceOf', [owner]) as Promise<bigint>
  }
}

export async function getLocalWalletClient(privateKey: Hash) {
  const account = privateKeyToAccount(privateKey)
  return createWalletClient({
    account,
    chain: hardhat,
    transport: http('http://127.0.0.1:8545'),
  })
}

export function exec(callback: () => Promise<void>) {
  callback()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error)
      process.exitCode = 1
    })
}

export function numberFixed(number: string | number, fixed = 2) {
  return Number(Number(number).toFixed(fixed))
}

export function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms))
}

export async function writeJson(path: string, data: unknown) {
  const jsonData = JSON.stringify(data, null, 2)
  return writeFile(path, jsonData, 'utf8')
}

export async function readJson(path: string) {
  const jsonData = await readFile(path, 'utf8')
  return JSON.parse(jsonData)
}
