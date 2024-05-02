import { ignition } from 'hardhat'
import BetChipModule from '../../ignition/modules/BetChip'
import { erc20Approve } from '../../utils'
import type { Address } from 'viem'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export async function deployBetChip(
  currencies: Address[],
  rates: bigint[],
) {
  const { BetChip } = await ignition.deploy(BetChipModule, {
    parameters: {
      BetChip: {
        currencies,
        rates,
      },
    },
  })
  return BetChip
}

export async function buyChip(
  owner: WalletClient,
  BetChip: ContractTypes['BetChip'],
  currency: Address,
  quantity: bigint,
) {
  const amount = await BetChip.read.getTokenAmount([currency, quantity])
  await erc20Approve(owner, currency, BetChip.address, amount)
  await BetChip.write.buy([currency, quantity], { account: owner.account })
}
