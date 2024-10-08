import { ignition, viem } from 'hardhat'
import BetChipManagerModule from '../../ignition/modules/BetChipManager'
import { erc20Approve } from '../../utils'
import type { Address, Hash } from 'viem'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export async function deployBetChipManager() {
  const { BetChipManager } = await ignition.deploy(BetChipManagerModule)
  return BetChipManager
}

export async function createBetChip(
  owner: WalletClient,
  BetChipManager: ContractTypes['BetChipManager'],
  token: Address,
) {
  const hash = await BetChipManager.write.createBetChip(
    [token],
    { account: owner.account },
  )
  return getBetChipByHash(hash, BetChipManager)
}

export async function getBetChipByHash(
  hash: Hash,
  BetChipManager: ContractTypes['BetChipManager'],
) {
  const publicClient = await viem.getPublicClient()
  const receipt = await publicClient.waitForTransactionReceipt({ hash })
  const logs = await publicClient.getLogs({
    address: BetChipManager.address,
    // @ts-expect-error
    event: BetChipManager.abi.find(item => item.name === 'BetChipCreated') as AbiEvent,
    fromBlock: receipt.blockNumber,
    toBlock: receipt.blockNumber,
    strict: true,
  })
  const log = logs.find(log => log.transactionHash === receipt.transactionHash)
  // @ts-expect-error
  const address = log?.args?.chip as Address
  return viem.getContractAt('BetChip', address)
}

export async function buyChip(
  owner: WalletClient,
  BetChip: ContractTypes['BetChip'],
  currency: Address,
  amount: bigint,
) {
  await erc20Approve(owner, currency, BetChip.address, amount)
  await BetChip.write.deposit([amount], { account: owner.account })
}
