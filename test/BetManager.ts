import { loadFixture, time } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  getAddress,
  isAddressEqual,
  parseUnits,
  zeroAddress,
} from 'viem'
import { deployBetGovToken } from './common'
import {
  BetDetails,
  createBet,
  deployBetManager,
} from './common/bet'
import { deployBetChip } from './common/chip'
import { deployBetVotingEscrow } from './common/vote'
import { testReceivable } from './asserts/Receivable'
import { testWithdrawable } from './asserts/Withdrawable'
import type { Address } from 'viem'
import type { ContractTypes } from '../types'

const DAY = 24n * 3600n
const DAY3 = 3n * DAY
const WEEK = 7n * DAY

describe('BetManager', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const BetChip = await deployBetChip([], [])
    const BetGovToken = await deployBetGovToken()
    const BetVotingEscrow = await deployBetVotingEscrow(BetGovToken.address)
    const BetManager = await deployBetManager(BetChip.address, BetVotingEscrow.address, BetGovToken.address)
    await BetVotingEscrow.write.setBetManager([BetManager.address])

    await BetGovToken.write.transfer([user.account.address, parseUnits('1000000', 18)])

    return {
      BetChip,
      BetGovToken,
      BetVotingEscrow,
      BetManager,
      publicClient,
      owner,
      user,
      hacker,
    }
  }

  describe('Ownable', () => {
    it('#owner()', async () => {
      const {
        BetManager,
        owner,
      } = await loadFixture(deployFixture)
      assert.equal(
        await BetManager.read.owner(),
        getAddress(owner.account.address),
      )
    })

    it('#transferOwnership()', async () => {
      const {
        BetManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetManager.write.transferOwnership([hacker.account.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetManager.write.transferOwnership([hacker.account.address], { account: owner.account })
      assert.equal(
        await BetManager.read.owner(),
        getAddress(hacker.account.address),
      )
    })
  })

  describe('Config contracts', () => {
    it('#betFactory() #setBetFactory()', async () => {
      const {
        BetManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetManager.write.setBetFactory([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetManager.write.setBetFactory([zeroAddress], { account: owner.account })
      assert.equal(
        await BetManager.read.betFactory(),
        zeroAddress,
      )
    })

    it('#betOptionFactory() #setBetOptionFactory()', async () => {
      const {
        BetManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetManager.write.setBetOptionFactory([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetManager.write.setBetOptionFactory([zeroAddress], { account: owner.account })
      assert.equal(
        await BetManager.read.betOptionFactory(),
        zeroAddress,
      )
    })

    it('#chip() #setChip()', async () => {
      const {
        BetManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetManager.write.setChip([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetManager.write.setChip([zeroAddress], { account: owner.account })
      assert.equal(
        await BetManager.read.chip(),
        zeroAddress,
      )
    })

    it('#vote() #setVote()', async () => {
      const {
        BetManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetManager.write.setVote([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetManager.write.setVote([zeroAddress], { account: owner.account })
      assert.equal(
        await BetManager.read.vote(),
        zeroAddress,
      )
    })

    it('#govToken() #setGovToken()', async () => {
      const {
        BetManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetManager.write.setGovToken([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetManager.write.setGovToken([zeroAddress], { account: owner.account })
      assert.equal(
        await BetManager.read.govToken(),
        zeroAddress,
      )
    })
  })

  describe('Bets management', () => {
    it('Creation restrictions', async () => {
      const {
        BetChip,
        BetManager,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      const MIN_OPTIONS_COUNT = await BetManager.read.minOptionsCount()
      const MAX_OPTIONS_COUNT = await BetManager.read.maxOptionsCount()
      const MIN_WAGERING_PERIOD_DURATION = await BetManager.read.minWageringPeriodDuration()
      const MAX_WAGERING_PERIOD_DURATION = await BetManager.read.maxWageringPeriodDuration()
      const MIN_DECISION_PERIOD_DURATION = await BetManager.read.minDecidingPeriodDuration()
      const MAX_DECISION_PERIOD_DURATION = await BetManager.read.maxDecidingPeriodDuration()

      const originWhitelist = [
        'https://example.com',
      ]
      const forumURL = 'https://example.com/foo'

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        await assert.isRejected(
          createBet(
            user,
            BetManager,
            Object.assign(
              {},
              BetDetails,
              {
                title: '',
              },
            ),
            MIN_WAGERING_PERIOD_DURATION,
            MIN_DECISION_PERIOD_DURATION,
            useChipERC20,
          ),
          'InvalidTitle',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            Object.assign(
              {},
              BetDetails,
              {
                description: '',
              },
            ),
            MIN_WAGERING_PERIOD_DURATION,
            MIN_DECISION_PERIOD_DURATION,
            useChipERC20,
          ),
          'InvalidDescription',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            Object.assign(
              {},
              BetDetails,
              {
                options: Array(MIN_OPTIONS_COUNT - 1n).fill(0n).map((_, i) => i.toString()),
              },
            ),
            WEEK,
            DAY3,
            useChipERC20,
          ),
          'InvalidOptionCount',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            Object.assign(
              {},
              BetDetails,
              {
                options: Array(MAX_OPTIONS_COUNT + 1n).fill(0n).map((_, i) => i.toString()),
              },
            ),
            WEEK,
            DAY3,
            useChipERC20,
          ),
          'InvalidOptionCount',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            Object.assign(
              {},
              BetDetails,
              {
                forumURL,
              },
            ),
            WEEK,
            DAY3,
            useChipERC20,
          ),
          'InvalidUrl',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            BetDetails,
            MIN_WAGERING_PERIOD_DURATION - 1n,
            MIN_DECISION_PERIOD_DURATION,
            useChipERC20,
          ),
          'InvalidWageringPeriodDuration',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            BetDetails,
            MAX_WAGERING_PERIOD_DURATION + 1n,
            MAX_DECISION_PERIOD_DURATION,
            useChipERC20,
          ),
          'InvalidWageringPeriodDuration',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            BetDetails,
            MIN_WAGERING_PERIOD_DURATION,
            MIN_DECISION_PERIOD_DURATION - 1n,
            useChipERC20,
          ),
          'InvalidDecidingPeriodDuration',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            BetDetails,
            MAX_WAGERING_PERIOD_DURATION,
            MAX_DECISION_PERIOD_DURATION + 1n,
            useChipERC20,
          ),
          'InvalidDecidingPeriodDuration',
        )
      }

      await assert.isRejected(
        BetManager.write.setOriginWhitelist([originWhitelist], { account: user.account }),
        'OwnableUnauthorizedAccount',
      )
      await BetManager.write.setOriginWhitelist([originWhitelist], { account: owner.account })

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          Object.assign(
            {},
            BetDetails,
            {
              forumURL,
            },
          ),
          WEEK,
          DAY3,
          useChipERC20,
        )
        assert.equal((await Bet.read.details()).forumURL, forumURL)
      }
    })

    it('Creation of a bet', async () => {
      const {
        BetManager,
        user,
      } = await loadFixture(deployFixture)
      const Bet = await createBet(
        user,
        BetManager,
        BetDetails,
        WEEK,
        DAY3,
        true,
      )

      assert.equal(await BetManager.read.isBet([BetManager.address]), false)
      assert.equal(await BetManager.read.isBet([Bet.address]), true)
    })

    it('Creating a bet requires a fee', async () => {
      const {
        BetGovToken,
        BetManager,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const fee = parseUnits('100', 18)
      await BetManager.write.setCreationFee([fee], { account: owner.account })

      await assert.isRejected(
        createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          true,
        ),
        'Underpayment',
      )

      await BetGovToken.write.approve([BetManager.address, fee], { account: user.account })
      const Bet = await createBet(
        user,
        BetManager,
        BetDetails,
        WEEK,
        DAY3,
        true,
      )

      assert.equal(await BetManager.read.isBet([BetManager.address]), false)
      assert.equal(await BetManager.read.isBet([Bet.address]), true)
    })

    it('The bet call is closed', async () => {
      const {
        BetManager,
        user,
      } = await loadFixture(deployFixture)

      const count = 10
      const bets: ContractTypes['Bet'][] = []
      for (let i = 0; i < count; i++) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
        )
        bets.push(Bet)
      }

      bets.reverse()

      const FirstBet = bets[0]
      const MiddleBet = bets[bets.length / 2]
      const LastBet = bets[bets.length - 1]

      assert.equal(await BetManager.read.activeBetIndex([FirstBet.address]), 1n)
      assert.equal(await BetManager.read.activeBetIndex([MiddleBet.address]), BigInt(bets.length / 2 + 1))
      assert.equal(await BetManager.read.activeBetIndex([LastBet.address]), BigInt(bets.length))

      await time.increase(WEEK)
      await FirstBet.write.release()
      await MiddleBet.write.release()
      await LastBet.write.release()

      assert.equal(await BetManager.read.betIndex([FirstBet.address]), 1n)
      assert.equal(await BetManager.read.betIndex([MiddleBet.address]), BigInt(bets.length / 2 + 1))
      assert.equal(await BetManager.read.betIndex([LastBet.address]), BigInt(bets.length))
      assert.equal(await BetManager.read.activeBetIndex([FirstBet.address]), 0n)
      assert.equal(await BetManager.read.activeBetIndex([MiddleBet.address]), 0n)
      assert.equal(await BetManager.read.activeBetIndex([LastBet.address]), 0n)

      const activeBets = bets
        .filter(bet => bet !== FirstBet && bet !== MiddleBet && bet !== LastBet)
        .map(bet => bet.address)
      assert.deepEqual(await BetManager.read.activeBets([0n, BigInt(activeBets.length)]), activeBets)
    })

    it('Search for bets', async () => {
      const {
        BetManager,
        user,
      } = await loadFixture(deployFixture)

      const count = 30
      const activeCount = 19
      const wageringCount = 6
      const cancelledCount = activeCount - wageringCount
      const closedCount = count - activeCount
      const bets: Address[] = []
      const activeBets: Address[] = []
      const wageringBets: Address[] = []
      const cancelledBets: Address[] = []
      const closedBets: Address[] = []
      for (let i = 0; i < count; i++) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          true,
        )
        bets.push(Bet.address)
        if (i < closedCount) {
          await time.increase(WEEK)
          await Bet.write.release()
          closedBets.push(Bet.address)
        } else {
          if (i < closedCount + cancelledCount) {
            await time.increase(WEEK)
            cancelledBets.push(Bet.address)
          } else {
            wageringBets.push(Bet.address)
          }
          activeBets.push(Bet.address)
        }
      }

      bets.reverse()
      activeBets.reverse()
      wageringBets.reverse()
      cancelledBets.reverse()
      closedBets.reverse()

      assert.equal(bets.length, count)
      assert.equal(activeBets.length, activeCount)
      assert.equal(wageringBets.length, wageringCount)
      assert.equal(cancelledBets.length, cancelledCount)
      assert.equal(closedBets.length, closedCount)

      assert.equal(await BetManager.read.betCount(), BigInt(count))
      assert.equal(await BetManager.read.activeBetCount(), BigInt(activeCount))
      assert.deepEqual(await BetManager.read.bets([0n, BigInt(count)]), bets)
      assert.deepEqual(await BetManager.read.bets([0n, BigInt(count), [0, 5, 6]]), bets)
      assert.deepEqual(await BetManager.read.bets([0n, BigInt(count), [0, 5]]), activeBets)
      assert.deepEqual(await BetManager.read.bets([0n, BigInt(count), [0]]), wageringBets)
      assert.deepEqual(await BetManager.read.bets([0n, BigInt(count), [5]]), cancelledBets)
      assert.deepEqual(await BetManager.read.bets([0n, BigInt(count), [6]]), closedBets)
      assert.deepEqual(await BetManager.read.bets([0n, BigInt(count), [5, 6]]), cancelledBets.concat(closedBets))
      assert.deepEqual(await BetManager.read.activeBets([0n, BigInt(activeCount)]), activeBets)
      assert.deepEqual(await BetManager.read.activeBets([0n, BigInt(activeCount), [0, 5]]), activeBets)
      assert.deepEqual(await BetManager.read.activeBets([0n, BigInt(activeCount), [0]]), wageringBets)
      assert.deepEqual(await BetManager.read.activeBets([0n, BigInt(activeCount), [5]]), cancelledBets)

      assert.equal(await BetManager.read.betIndex([BetManager.address]), 0n)
      assert.equal(await BetManager.read.betAt([0n]), zeroAddress)
      for (const [i, bet] of Object.entries(bets)) {
        assert.equal(await BetManager.read.isBet([bet]), true)
        assert.equal(await BetManager.read.betIndex([bet]), BigInt(i) + 1n)
        assert.equal(await BetManager.read.betAt([BigInt(i) + 1n]), bet)

        if (!activeBets.includes(bet)) {
          assert.equal(await BetManager.read.activeBetIndex([bet]), 0n)
        }
      }

      assert.equal(await BetManager.read.activeBetIndex([BetManager.address]), 0n)
      assert.equal(await BetManager.read.activeBetAt([0n]), zeroAddress)
      for (const [i, bet] of Object.entries(activeBets)) {
        assert.equal(await BetManager.read.isBet([bet]), true)
        assert.equal(await BetManager.read.activeBetIndex([bet]), BigInt(i) + 1n)
        assert.equal(await BetManager.read.activeBetAt([BigInt(i) + 1n]), bet)
      }

      // Paging of the bets
      {
        const pageSize = 6
        const pageCount = Math.ceil(count / pageSize)
        for (let i = 0; i < pageCount; i++) {
          const offset = i * pageSize
          const matchedBets = await BetManager.read.bets([BigInt(offset), BigInt(pageSize)])
          assert.deepEqual(matchedBets, bets.slice(offset, offset + pageSize))
        }
      }

      // Paging of the bets by status
      {
        const pageSize = 4
        let lastIndex = 0
        let i = 0
        while (true) {
          const offset = activeCount + i * pageSize
          const matchedBets = (await BetManager.read.bets([BigInt(lastIndex), BigInt(pageSize), [6]])) as Address[]
          assert.deepEqual(matchedBets, bets.slice(offset, offset + pageSize))
          if (matchedBets.length < pageSize) break
          const lastBet = matchedBets[matchedBets.length - 1]
          lastIndex = Number(await BetManager.read.betIndex([lastBet]))
          i++
        }
      }

      // Paging of the active bets
      {
        const pageSize = 4
        const pageCount = Math.ceil(activeCount / pageSize)
        for (let i = 0; i < pageCount; i++) {
          const offset = i * pageSize
          const matchedBets = await BetManager.read.activeBets([BigInt(offset), BigInt(pageSize)])
          assert.deepEqual(matchedBets, activeBets.slice(offset, offset + pageSize))
        }
      }

      // Paging of the active bets by status
      {
        const pageSize = 4
        let lastIndex = 0
        let i = 0
        while (true) {
          const offset = wageringCount + i * pageSize
          const matchedBets = (await BetManager.read.activeBets([BigInt(lastIndex), BigInt(pageSize), [5]])) as Address[]
          assert.deepEqual(matchedBets, activeBets.slice(offset, offset + pageSize))
          if (matchedBets.length < pageSize) break
          const lastBet = matchedBets[matchedBets.length - 1]
          lastIndex = Number(await BetManager.read.activeBetIndex([lastBet]))
          i++
        }
      }
    })
  })

  testReceivable(async () => {
    const { BetManager, owner } = await loadFixture(deployFixture)
    return {
      Receivable: BetManager as unknown as ContractTypes['Receivable'],
      owner,
    }
  })

  testWithdrawable(async () => {
    const { BetManager, owner } = await loadFixture(deployFixture)
    return {
      Withdrawable: BetManager as unknown as ContractTypes['Withdrawable'],
      owner,
    }
  })
})
