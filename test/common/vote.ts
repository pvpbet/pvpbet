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

export enum UnlockWaitingPeriod {
  NONE,
  WEEK,
  WEEK12,
}

export async function deployBetVotingEscrow(
  govToken: Address,
) {
  const { BetVotingEscrow } = await ignition.deploy(BetVotingEscrowModule, {
    parameters: {
      BetVotingEscrow: {
        govToken,
      },
    },
  })
  return BetVotingEscrow
}

export async function stake(
  owner: WalletClient,
  BetGovToken: ContractTypes['BetGovToken'],
  BetVotingEscrow: ContractTypes['BetVotingEscrow'],
  unlockWaitingPeriod: UnlockWaitingPeriod,
  amount: bigint,
) {
  await BetGovToken.write.approve([BetVotingEscrow.address, amount], { account: owner.account })
  await BetVotingEscrow.write.stake([unlockWaitingPeriod, amount], { account: owner.account })
}

export async function unstake(
  owner: WalletClient,
  BetVotingEscrow: ContractTypes['BetVotingEscrow'],
  unlockWaitingPeriod: UnlockWaitingPeriod,
  amount: bigint | undefined = undefined,
) {
  typeof amount === 'bigint'
    ? await BetVotingEscrow.write.unstake([unlockWaitingPeriod, amount], { account: owner.account })
    : await BetVotingEscrow.write.unstake([unlockWaitingPeriod], { account: owner.account })
}

export async function withdraw(
  owner: WalletClient,
  BetVotingEscrow: ContractTypes['BetVotingEscrow'],
) {
  await BetVotingEscrow.write.withdraw({ account: owner.account })
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
