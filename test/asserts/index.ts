import { assert } from 'chai'
import { getBalance, numberFixed } from '../../utils'
import { isAddressEqual, formatEther, zeroAddress } from 'viem'
import { BetStatus } from '../common/bet'
import type { Address } from 'viem'
import type { ContractTypes } from '../../types'

export async function checkBalance(
  exec: () => Promise<void>,
  accounts: [owner: Address, token: Address, diff: bigint][],
) {
  const balances = await Promise.all(
    accounts.map(([owner, token]) => getBalance(token, owner)),
  )
  await exec()
  const newBalances = await Promise.all(
    accounts.map(([owner, token]) => getBalance(token, owner)),
  )
  accounts.forEach(([, token, diff], i) => {
    const actualDiff = newBalances[i] - balances[i]
    if (isAddressEqual(zeroAddress, token)) {
      assert.equal(
        numberFixed(
          formatEther(actualDiff),
        ),
        numberFixed(
          formatEther(diff),
        ),
      )
    } else {
      assert.equal(
        actualDiff,
        diff,
      )
    }
  })
}

export async function checkVoteLevel(
  BetVotingEscrow: ContractTypes['BetVotingEscrow'],
  exec: () => Promise<void>,
  accounts: [owner: Address, diff: bigint][],
) {
  const levels = await Promise.all(
    accounts.map(([owner]) => {
      return BetVotingEscrow.read.level([owner])
    }),
  )
  await exec()
  const newLevels = await Promise.all(
    accounts.map(([owner]) => {
      return BetVotingEscrow.read.level([owner])
    }),
  )
  accounts.forEach(([, diff], i) => {
    assert.equal(
      newLevels[i],
      levels[i] + diff,
    )
  })
}

export async function isBetClosed(
  Bet: ContractTypes['Bet'],
  chip: Address,
) {
  assert.equal(await Bet.read.status(), BetStatus.CLOSED)
  assert.equal(await Bet.read.released(), true)
  assert.equal(await getBalance(chip, Bet.address), 0n)
  const options = await Bet.read.options()
  for (const option of options) {
    assert.equal(await getBalance(chip, option), 0n)
  }
}

export async function isCorrectStakeReward(
  BetVotingEscrow: ContractTypes['BetVotingEscrow'],
  GovTokenStaking: ContractTypes['GovTokenStaking'],
  chip: Address,
  owners: Address[],
  total: bigint,
) {
  const stakedTotalWeight = await GovTokenStaking.read.stakedWeight()
  for (const owner of owners) {
    const unclaimedRewards = await BetVotingEscrow.read.unclaimedRewards([owner, chip])
    const stakedWeight = await GovTokenStaking.read.stakedWeight([owner])
    // An error margin of 1 is allowed.
    assert.closeTo(Number(unclaimedRewards - total * stakedWeight / stakedTotalWeight), 0, 1)
  }
}
