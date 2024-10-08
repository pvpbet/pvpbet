import { ignition } from 'hardhat'
import { isAddressEqual, zeroAddress } from 'viem'
import { erc20Approve } from '../../utils'
import GovTokenStakingModule from '../../ignition/modules/GovTokenStaking'
import type { Address } from 'viem'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export enum UnlockWaitingPeriod {
  NONE,
  WEEK,
  WEEK12,
}

export async function deployGovTokenStaking(
  VotingEscrow: Address,
  GovToken: Address,
  chip: Address,
) {
  const { GovTokenStaking } = await ignition.deploy(GovTokenStakingModule, {
    parameters: {
      GovTokenStaking: {
        VotingEscrow,
        GovToken,
        rewardTokens: [
          zeroAddress,
          chip,
        ],
      },
    },
  })
  return GovTokenStaking
}

export async function stake(
  owner: WalletClient,
  GovToken: ContractTypes['GovToken'],
  GovTokenStaking: ContractTypes['GovTokenStaking'],
  unlockWaitingPeriod: UnlockWaitingPeriod,
  amount: bigint,
) {
  await GovToken.write.approve([GovTokenStaking.address, amount], { account: owner.account })
  await GovTokenStaking.write.stake([unlockWaitingPeriod, amount], { account: owner.account })
}

export async function unstake(
  owner: WalletClient,
  GovTokenStaking: ContractTypes['GovTokenStaking'],
  unlockWaitingPeriod: UnlockWaitingPeriod,
  amount: bigint | undefined = undefined,
) {
  typeof amount === 'bigint'
    ? await GovTokenStaking.write.unstake([unlockWaitingPeriod, amount], { account: owner.account })
    : await GovTokenStaking.write.unstake([unlockWaitingPeriod], { account: owner.account })
}

export async function withdraw(
  owner: WalletClient,
  GovTokenStaking: ContractTypes['GovTokenStaking'],
) {
  await GovTokenStaking.write.withdraw({ account: owner.account })
}

export async function distribute(
  owner: WalletClient,
  GovTokenStaking: ContractTypes['GovTokenStaking'],
  token: Address,
  amount: bigint,
) {
  if (isAddressEqual(zeroAddress, token)) {
    await GovTokenStaking.write.distribute({ account: owner.account, value: amount })
  } else {
    await erc20Approve(owner, token, GovTokenStaking.address, amount)
    await GovTokenStaking.write.distribute([token, amount], { account: owner.account })
  }
}
