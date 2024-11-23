import { ignition, viem } from 'hardhat'
import BetManagerModule from '../../ignition/modules/BetManager'
import { transfer } from '../../utils'
import { zeroAddress } from 'viem'
import type {
  AbiEvent,
  Address,
  Hash,
} from 'viem'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export enum BetStatus {
  WAGERING,
  VERIFYING,
  ANNOUNCEMENT,
  ARBITRATING,
  CONFIRMED,
  CANCELLED,
  CLOSED,
}

export const BetDetails = {
  title: 'Musk VS Zuckerberg',
  description: 'Musk VS Zuckerberg, who will win?',
  iconURL: 'https://cf-img-a-in.tosshub.com/sites/visualstory/stories/2023_06/story_45383/assets/4.jpeg',
  forumURL: '',
  options: [
    'Musk',
    'Zuckerberg',
    'Draw',
  ],
}

export async function deployBetManager(
  BetChipManager: Address,
  VotingEscrow: Address,
  GovToken: Address,
) {
  const { BetManager } = await ignition.deploy(BetManagerModule, {
    parameters: {
      BetManager: {
        BetChipManager,
        VotingEscrow,
        GovToken,
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
  verifyingPeriodDuration: bigint,
  chip?: Address,
) {
  const hash = await BetManager.write.createBet(
    [
      details,
      wageringPeriodDuration,
      verifyingPeriodDuration,
      chip || zeroAddress,
    ],
    { account: owner.account },
  )
  return getBetByHash(hash, BetManager)
}

export async function getBetByHash(
  hash: Hash,
  BetManager: ContractTypes['BetManager'],
) {
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
  return viem.getContractAt('Bet', address)
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

export async function verify(
  vote: Address,
  accounts: [wallet: WalletClient, option: Address, ratio: bigint][],
  Bet: ContractTypes['Bet'],
) {
  const total = await Bet.read.minVerifiedTotalAmount()
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
  const total = await Bet.read.minDisputedTotalAmount()
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
  const betConfig = await Bet.read.config()
  const wageredTotalAmount = await Bet.read.wageredTotalAmount()
  return wageredTotalAmount * betConfig.creatorRewardRatio / 100n
}

export async function getVerifierReward(
  Bet: ContractTypes['Bet'],
  owner: Address,
) {
  const Option = await getConfirmedWinningOption(Bet)
  const winningOptionVerifiedAmount = (await Option.read.verifiedAmount()) as bigint
  const ownerVerifiedAmount = (await Option.read.verifiedAmount([owner])) as bigint

  const betConfig = await Bet.read.config()
  const wageredTotalAmount = await Bet.read.wageredTotalAmount()
  const verifierReward = wageredTotalAmount * betConfig.verifierRewardRatio / 100n
  return verifierReward * ownerVerifiedAmount / winningOptionVerifiedAmount
}

export async function getWinnerReward(
  Bet: ContractTypes['Bet'],
  owner: Address,
) {
  const Option = await getConfirmedWinningOption(Bet)
  const winningOptionWageredAmount = (await Option.read.wageredAmount()) as bigint
  const ownerWageredAmount = (await Option.read.wageredAmount([owner])) as bigint

  const betConfig = await Bet.read.config()
  const wageredTotalAmount = await Bet.read.wageredTotalAmount()
  const protocolReward = wageredTotalAmount * betConfig.creatorRewardRatio / 100n
  const creatorReward = wageredTotalAmount * betConfig.creatorRewardRatio / 100n
  const verifierReward = wageredTotalAmount * betConfig.verifierRewardRatio / 100n
  const winnerReward = wageredTotalAmount - protocolReward - creatorReward - verifierReward
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

  const VerifiedOption = await getUnconfirmedWinningOption(Bet)
  const verifiedAmount = (await VerifiedOption.read.verifiedAmount()) as bigint
  return verifiedAmount * ownerArbitratedAmount / winningOptionArbitratedAmount
}
