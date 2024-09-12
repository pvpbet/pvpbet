import { ignition } from 'hardhat'
import BetChipModule from '../../ignition/modules/BetChip'
import { erc20Approve } from '../../utils'
import type { Address } from 'viem'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export async function deployBetChip(currency: Address) {
  const { BetChip } = await ignition.deploy(BetChipModule, {
    parameters: {
      BetChip: {
        currency,
      },
    },
  })
  return BetChip
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
