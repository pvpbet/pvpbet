import { ignition } from 'hardhat'
import BetVotingEscrowModule from '../../ignition/modules/BetVotingEscrow'
import { erc20Approve } from '../../utils'
import {
  isAddressEqual,
  zeroAddress,
} from 'viem'
import type { Address } from 'viem'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export async function deployBetVotingEscrow() {
  const { BetVotingEscrow } = await ignition.deploy(BetVotingEscrowModule)
  return BetVotingEscrow
}

export async function distribute(
  owner: WalletClient,
  BetVotingEscrow: ContractTypes['BetVotingEscrow'],
  token: Address,
  amount: bigint,
) {
  if (isAddressEqual(zeroAddress, token)) {
    await BetVotingEscrow.write.distribute({ account: owner.account, value: amount })
  } else {
    await erc20Approve(owner, token, BetVotingEscrow.address, amount)
    await BetVotingEscrow.write.distribute([token, amount], { account: owner.account })
  }
}
