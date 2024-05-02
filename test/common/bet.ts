import { ignition, viem } from 'hardhat'
import BetManagerModule from '../../ignition/modules/BetManager'
import { parseUnits } from 'viem'
import { transfer } from '../../utils'
import type {
  AbiEvent,
  Address,
} from 'viem'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export enum BetStatus {
  WAGERING,
  DECIDING,
  ANNOUNCEMENT,
  ARBITRATING,
  CONFIRMED,
  CANCELLED,
  CLOSED,
}

export const BetDetails = {
  title: 'Musk VS Zuckerberg',
  description: 'Musk VS Zuckerberg, who will win?',
  iconURL: 'https://example.com/icons/icon.png',
  forumURL: '',
  options: [
    'Musk',
    'Zuckerberg',
    'Draw',
  ],
}

export async function deployBetManager(
  chip: Address,
  vote: Address,
  govToken: Address,
) {
  const { BetManager } = await ignition.deploy(BetManagerModule, {
    parameters: {
      BetManager: {
        chip,
        vote,
        govToken,
      },
    },
  })
  return BetManager
}

export async function createBet(
  owner: WalletClient,
  BetManager: ContractTypes['BetManager'],
  details: typeof BetDetails,
  wageringPeriodDuration: bigint,
  decidingPeriodDuration: bigint,
  useChipERC20: boolean = false,
) {
  const hash = await BetManager.write.createBet(
    [
      details,
      wageringPeriodDuration,
      decidingPeriodDuration,
      useChipERC20,
    ],
    { account: owner.account },
  )
  const publicClient = await viem.getPublicClient()
  const receipt = await publicClient.waitForTransactionReceipt({ hash })
  const logs = await publicClient.getLogs({
    address: BetManager.address,
    // @ts-expect-error
    event: BetManager.abi.find(item => item.name === 'BetCreated') as AbiEvent,
    fromBlock: receipt.blockNumber,
    toBlock: receipt.blockNumber,
    strict: true,
  })
  const log = logs.find(log => log.transactionHash === receipt.transactionHash)
  // @ts-expect-error
  const address = log?.args?.bet as Address
  return viem.getContractAt(
    'Bet',
    address,
  )
}

export async function getBetOption(
  address: Address,
) {
  return viem.getContractAt(
    'BetOption',
    address,
  )
}

export async function getUnconfirmedWinningOption(Bet: ContractTypes['Bet']): Promise<ContractTypes['BetOption']> {
  const option = await Bet.read.unconfirmedWinningOption()
  return getBetOption(option)
}

export async function getConfirmedWinningOption(Bet: ContractTypes['Bet']): Promise<ContractTypes['BetOption']> {
  const option = await Bet.read.confirmedWinningOption()
  return getBetOption(option)
}

export async function wager(
  chip: Address,
  accounts: [wallet: WalletClient, option: Address, ratio: bigint][],
  Bet: ContractTypes['Bet'],
) {
  const total = await Bet.read.minWageredTotalAmount()
  const amounts = []
  for (const [wallet, option, ratio] of accounts) {
    const amount = total * ratio / 10n
    if (amount) {
      await transfer(wallet, chip, option, amount)
      amounts.push(amount)
    }
  }
  return amounts
}

export async function decide(
  vote: Address,
  accounts: [wallet: WalletClient, option: Address, ratio: bigint][],
  total: bigint = parseUnits('10000', 18),
) {
  const amounts = []
  for (const [wallet, option, ratio] of accounts) {
    const amount = total * ratio / 10n
    if (amount) {
      await transfer(wallet, vote, option, amount)
      amounts.push(amount)
    }
  }
  return amounts
}

export async function dispute(
  chip: Address,
  accounts: [wallet: WalletClient, ratio: bigint][],
  Bet: ContractTypes['Bet'],
) {
  const wageredTotalAmount = await Bet.read.wageredTotalAmount()
  const DISPUTE_TRIGGER_AMOUNT_RATIO = await Bet.read.DISPUTE_TRIGGER_AMOUNT_RATIO()
  const total = wageredTotalAmount * DISPUTE_TRIGGER_AMOUNT_RATIO / 100n
  const amounts = []
  for (const [wallet, ratio] of accounts) {
    const amount = total * ratio / 10n
    if (amount) {
      await transfer(wallet, chip, Bet.address, amount)
      amounts.push(amount)
    }
  }
  return amounts
}

export async function arbitrate(
  vote: Address,
  accounts: [wallet: WalletClient, option: Address, ratio: bigint][],
) {
  for (const [wallet, option, ratio] of accounts) {
    if (ratio) {
      await transfer(wallet, vote, option, ratio)
    }
  }
}

export async function getCreatorReward(
  Bet: ContractTypes['Bet'],
) {
  const CREATOR_REWARD_RATIO = await Bet.read.CREATOR_REWARD_RATIO()
  const wageredTotalAmount = await Bet.read.wageredTotalAmount()
  return wageredTotalAmount * CREATOR_REWARD_RATIO / 100n
}

export async function getDeciderReward(
  Bet: ContractTypes['Bet'],
  owner: Address,
) {
  const Option = await getConfirmedWinningOption(Bet)
  const winningOptionDecidedAmount = await Option.read.decidedAmount()
  const ownerDecidedAmount = await Option.read.decidedAmount([owner])

  const DECIDER_REWARD_RATIO = await Bet.read.DECIDER_REWARD_RATIO()
  const wageredTotalAmount = await Bet.read.wageredTotalAmount()
  const deciderReward = wageredTotalAmount * DECIDER_REWARD_RATIO / 100n
  return deciderReward * ownerDecidedAmount / winningOptionDecidedAmount
}

export async function getWinnerReward(
  Bet: ContractTypes['Bet'],
  owner: Address,
) {
  const Option = await getConfirmedWinningOption(Bet)
  const winningOptionWageredAmount = await Option.read.wageredAmount()
  const ownerWageredAmount = await Option.read.wageredAmount([owner])

  const PROTOCOL_REWARD_RATIO = await Bet.read.PROTOCOL_REWARD_RATIO()
  const CREATOR_REWARD_RATIO = await Bet.read.CREATOR_REWARD_RATIO()
  const DECIDER_REWARD_RATIO = await Bet.read.DECIDER_REWARD_RATIO()
  const wageredTotalAmount = await Bet.read.wageredTotalAmount()
  const protocolReward = wageredTotalAmount * PROTOCOL_REWARD_RATIO / 100n
  const creatorReward = wageredTotalAmount * CREATOR_REWARD_RATIO / 100n
  const deciderReward = wageredTotalAmount * DECIDER_REWARD_RATIO / 100n
  const winnerReward = wageredTotalAmount - protocolReward - creatorReward - deciderReward
  return winnerReward * ownerWageredAmount / winningOptionWageredAmount
}

export async function getConfiscatedChipReward(
  Bet: ContractTypes['Bet'],
  owner: Address,
) {
  const Option = await getConfirmedWinningOption(Bet)
  const winningOptionArbitratedAmount = (await Option.read.arbitratedAmount()) as bigint
  const ownerArbitratedAmount = (await Option.read.arbitratedAmount([owner])) as bigint

  const disputedAmount = (await Bet.read.disputedAmount()) as bigint
  return disputedAmount * ownerArbitratedAmount / winningOptionArbitratedAmount
}

export async function getConfiscatedVoteReward(
  Bet: ContractTypes['Bet'],
  owner: Address,
) {
  const Option = await getConfirmedWinningOption(Bet)
  const winningOptionArbitratedAmount = (await Option.read.arbitratedAmount()) as bigint
  const ownerArbitratedAmount = (await Option.read.arbitratedAmount([owner])) as bigint

  const DecidedOption = await getUnconfirmedWinningOption(Bet)
  const decidedAmount = (await DecidedOption.read.decidedAmount()) as bigint
  return decidedAmount * ownerArbitratedAmount / winningOptionArbitratedAmount
}
