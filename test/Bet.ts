import { loadFixture, time } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  getAddress,
  isAddress,
  isAddressEqual,
  parseEther,
  parseUnits,
  zeroAddress,
} from 'viem'
import { transfer } from '../utils'
import {
  claimTestTokens,
  deployGovToken,
  deployTestTokens,
} from './common'
import {
  BetDetails,
  BetStatus,
  createBet,
  arbitrate,
  deployBetManager,
  dispute,
  getBetOption,
  getConfiscatedChipReward,
  getConfiscatedVoteReward,
  getCreatorReward,
  getDeciderReward,
  getWinnerReward,
  decide,
  wager,
} from './common/bet'
import {
  buyChip,
  deployBetChip,
} from './common/chip'
import {
  UnlockWaitingPeriod,
  deployGovTokenStaking,
  stake,
} from './common/staking'
import { deployBetVotingEscrow } from './common/vote'
import {
  checkBalance,
  checkVoteLevel,
  isBetClosed,
  isCorrectStakeReward,
} from './asserts'

const DAY = 24n * 3600n
const DAY3 = 3n * DAY
const WEEK = 7n * DAY

describe('Bet', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const testTokens = await deployTestTokens()
    await claimTestTokens(owner, testTokens)
    await claimTestTokens(user, testTokens)
    await claimTestTokens(hacker, testTokens)

    const { DAI, USDC } = testTokens
    const currencies = [
      getAddress(DAI.address),
      getAddress(USDC.address),
    ]
    const rates = [
      1n,
      10n ** 12n,
    ]
    const BetChip = await deployBetChip(currencies, rates)
    const GovToken = await deployGovToken()
    const BetVotingEscrow = await deployBetVotingEscrow()
    const GovTokenStaking = await deployGovTokenStaking(GovToken.address, BetVotingEscrow.address)
    const BetManager = await deployBetManager(GovToken.address, BetChip.address, BetVotingEscrow.address)

    await BetVotingEscrow.write.setBetManager([BetManager.address])
    await BetVotingEscrow.write.setGovTokenStaking([GovTokenStaking.address])
    await GovToken.write.transfer([user.account.address, parseUnits('1000000', 18)])
    await GovToken.write.transfer([hacker.account.address, parseUnits('1000000', 18)])

    await Promise.all(
      [
        owner,
        user,
        hacker,
      ].map(async wallet => {
        await stake(
          wallet,
          GovToken,
          GovTokenStaking,
          UnlockWaitingPeriod.WEEK12,
          parseUnits('500000', 18),
        )
        await buyChip(
          wallet,
          BetChip,
          DAI.address,
          parseUnits('100000', 18),
        )
      }),
    )

    return {
      ...testTokens,
      BetChip,
      BetVotingEscrow,
      BetManager,
      GovToken,
      GovTokenStaking,
      publicClient,
      owner,
      user,
      hacker,
    }
  }

  describe('Creation', () => {
    it('Initial state after creation', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        user,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const currentTime = BigInt(await time.latest())
        assert.equal(await Bet.read.isBet(), true)
        assert.equal(await Bet.read.bet(), Bet.address)
        assert.equal(await Bet.read.chip(), chip)
        assert.equal(await Bet.read.vote(), BetVotingEscrow.address)
        assert.equal(await Bet.read.creator(), getAddress(user.account.address))
        assert.equal(await Bet.read.wageringPeriodDeadline(), currentTime + WEEK)
        assert.equal(await Bet.read.decidingPeriodDeadline(), currentTime + WEEK + DAY3)
        assert.equal(await Bet.read.unconfirmedWinningOption(), zeroAddress)
        assert.equal(await Bet.read.confirmedWinningOption(), zeroAddress)
        assert.equal(await Bet.read.wageredTotalAmount(), 0n)
        assert.equal(await Bet.read.status(), BetStatus.WAGERING)
        assert.equal(await Bet.read.statusDeadline(), currentTime + WEEK)
        assert.equal(await Bet.read.released(), false)
        assert.deepEqual(await Bet.read.details(), BetDetails)

        const options = await Bet.read.options()
        assert.equal(options.length, BetDetails.options.length)
        for (let i = 0; i < options.length; i++) {
          const option = options[i]
          assert.equal(isAddress(option), true)
          const BetOption = await getBetOption(option)
          assert.equal(await BetOption.read.bet(), Bet.address)
          assert.equal(await BetOption.read.description(), BetDetails.options[i])
          assert.equal(await BetOption.read.chip(), chip)
          assert.equal(await BetOption.read.vote(), BetVotingEscrow.address)
          assert.equal(await BetOption.read.chipMinValue(), await Bet.read.chipMinValue())
          assert.equal(await BetOption.read.voteMinValue(), await Bet.read.voteMinValue())
        }
      }
    })
  })

  describe('Wager', () => {
    it('Preventing dust attacks', async () => {
      const {
        BetChip,
        BetManager,
        user,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        const wageredAmount = await Bet.read.chipMinValue()
        await assert.isRejected(
          transfer(user, chip, Bet.address, wageredAmount - 1n),
          'AnnouncementPeriodHasNotStartedYet',
        )
        await assert.isRejected(
          transfer(user, chip, options[0], wageredAmount - 1n),
          'InvalidAmount',
        )
      }
    })

    it('Successful wager', async () => {
      const {
        BetChip,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await assert.isRejected(
          transfer(user, chips.filter(item => !isAddressEqual(item, chip))[0], options[0], 1n),
          'InvalidChip',
        )

        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)
      }
    })

    it('Invalid wager', async () => {
      const {
        BetChip,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        {
          const Bet = await createBet(
            user,
            BetManager,
            BetDetails,
            WEEK,
            DAY3,
            useChipERC20,
          )
          const options = await Bet.read.options()
          // Insufficient wagered amount
          await wager(chip, [
            [user, options[0], 8n],
            [hacker, options[1], 1n],
          ], Bet)
          await time.increaseTo(await Bet.read.statusDeadline() + 1n)
          assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
        }

        {
          const Bet = await createBet(
            user,
            BetManager,
            BetDetails,
            WEEK,
            DAY3,
            useChipERC20,
          )
          const options = await Bet.read.options()
          // Invalid wagered ratio
          await wager(chip, [
            [user, options[0], 10n],
          ], Bet)
          await time.increaseTo(await Bet.read.statusDeadline() + 1n)
          assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
        }

        {
          const Bet = await createBet(
            user,
            BetManager,
            BetDetails,
            WEEK,
            DAY3,
            useChipERC20,
          )
          const options = await Bet.read.options()
          // Invalid wagered ratio
          await wager(chip, [
            [owner, options[0], 1n],
            [user, options[1], 9n],
            [hacker, options[1], 1n],
          ], Bet)
          await time.increaseTo(await Bet.read.statusDeadline() + 1n)
          assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
        }
      }
    })

    it('Failed wager', async () => {
      const {
        BetChip,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        {
          const Bet = await createBet(
            user,
            BetManager,
            BetDetails,
            WEEK,
            DAY3,
            useChipERC20,
          )
          const options = await Bet.read.options()
          await wager(chip, [
            [owner, options[0], 2n],
            [user, options[1], 9n],
            [hacker, options[1], 1n],
          ], Bet)
          await time.increaseTo(await Bet.read.statusDeadline() + 1n)
          assert.equal(await Bet.read.status(), BetStatus.DECIDING)
          await assert.isRejected(
            transfer(user, chip, Bet.address, 1n),
            'AnnouncementPeriodHasNotStartedYet',
          )
          await assert.isRejected(
            transfer(user, chip, options[0], 1n),
            'WageringPeriodHasAlreadyEnded',
          )
        }

        {
          const Bet = await createBet(
            user,
            BetManager,
            BetDetails,
            WEEK,
            DAY3,
            useChipERC20,
          )
          const options = await Bet.read.options()
          await time.increaseTo(await Bet.read.statusDeadline() + 1n)
          assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
          await assert.isRejected(
            transfer(user, chip, Bet.address, 1n),
            'CannotReceive',
          )
          await assert.isRejected(
            transfer(user, chip, options[0], 1n),
            'CannotReceive',
          )
        }
      }
    })

    it('Expired wager', async () => {
      const {
        BetChip,
        BetManager,
        user,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }
    })

    it('Wagered records', async () => {
      const {
        BetChip,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        const [
          ownerWageredAmount,
          userWageredAmount,
          hackerWageredAmount,
        ] = await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        const BetOption1 = await getBetOption(options[0])
        const BetOption2 = await getBetOption(options[1])

        assert.equal(
          await Bet.read.wageredTotalAmount(),
          ownerWageredAmount + userWageredAmount + hackerWageredAmount,
        )
        assert.equal(await BetOption1.read.wageredAmount(), ownerWageredAmount)
        assert.equal(
          await BetOption2.read.wageredAmount(),
          userWageredAmount + hackerWageredAmount,
        )
        assert.equal(
          await BetOption1.read.wageredAmount([owner.account.address]),
          ownerWageredAmount,
        )
        assert.equal(
          await BetOption2.read.wageredAmount([user.account.address]),
          userWageredAmount,
        )
        assert.equal(
          await BetOption2.read.wageredAmount([hacker.account.address]),
          hackerWageredAmount,
        )
        assert.deepEqual(await BetOption1.read.wageredRecords(), [
          {
            account: getAddress(owner.account.address),
            amount: ownerWageredAmount,
          },
        ])
        assert.deepEqual(await BetOption2.read.wageredRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userWageredAmount,
          },
          {
            account: getAddress(hacker.account.address),
            amount: hackerWageredAmount,
          },
        ])

        // Cancel the wager
        await checkBalance(
          async () => {
            await transfer(hacker, chip, BetOption2.address, 0n)
          },
          [
            [hacker.account.address, chip, hackerWageredAmount],
          ],
        )
        assert.equal(
          await BetOption2.read.wageredAmount([hacker.account.address]),
          0n,
        )
        assert.deepEqual(await BetOption2.read.wageredRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userWageredAmount,
          },
        ])
      }
    })
  })

  describe('Decision', () => {
    it('Preventing dust attacks', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        const decidedAmount = await Bet.read.voteMinValue()
        await assert.isRejected(
          transfer(user, BetVotingEscrow.address, Bet.address, decidedAmount - 1n),
          'InvalidStatus',
        )
        await assert.isRejected(
          transfer(user, BetVotingEscrow.address, options[1], decidedAmount - 1n),
          'InvalidAmount',
        )
      }
    })

    it('Successful Decision', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)
      }
    })

    it('Invalid Decision', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }
    })

    it('Failed Decision', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.WAGERING)

        const decidedAmount = parseUnits('1000', 18)
        await assert.isRejected(
          transfer(user, BetVotingEscrow.address, options[1], decidedAmount),
          'InvalidStatus',
        )

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await transfer(user, BetVotingEscrow.address, options[1], decidedAmount)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await assert.isRejected(
          transfer(user, BetVotingEscrow.address, options[1], decidedAmount),
          'InvalidStatus',
        )
      }
    })

    it('Expired Decision', async () => {
      const {
        BetChip,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }
    })

    it('Decided records', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        const [
          ownerDecidedAmount,
          userDecidedAmount,
          hackerDecidedAmount,
        ] = await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        const BetOption1 = await getBetOption(options[0])
        const BetOption2 = await getBetOption(options[1])

        assert.equal(await BetOption1.read.decidedAmount(), ownerDecidedAmount)
        assert.equal(
          await BetOption2.read.decidedAmount(),
          userDecidedAmount + hackerDecidedAmount,
        )
        assert.equal(
          await BetOption1.read.decidedAmount([owner.account.address]),
          ownerDecidedAmount,
        )
        assert.equal(
          await BetOption2.read.decidedAmount([user.account.address]),
          userDecidedAmount,
        )
        assert.equal(
          await BetOption2.read.decidedAmount([hacker.account.address]),
          hackerDecidedAmount,
        )
        assert.deepEqual(await BetOption1.read.decidedRecords(), [
          {
            account: getAddress(owner.account.address),
            amount: ownerDecidedAmount,
          },
        ])
        assert.deepEqual(await BetOption2.read.decidedRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userDecidedAmount,
          },
          {
            account: getAddress(hacker.account.address),
            amount: hackerDecidedAmount,
          },
        ])

        // Cancel the decision
        await checkBalance(
          async () => {
            await transfer(hacker, BetVotingEscrow.address, BetOption2.address, 0n)
          },
          [
            [hacker.account.address, BetVotingEscrow.address, hackerDecidedAmount],
          ],
        )
        assert.equal(
          await BetOption2.read.decidedAmount([hacker.account.address]),
          0n,
        )
        assert.deepEqual(await BetOption2.read.decidedRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userDecidedAmount,
          },
        ])
      }
    })
  })

  describe('Announcement', () => {
    it('Expired announcement', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)
      }
    })
  })

  describe('Dispute', () => {
    it('Preventing dust attacks', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        const disputedAmount = await Bet.read.chipMinValue()
        await assert.isRejected(
          transfer(user, chip, Bet.address, disputedAmount - 1n),
          'InvalidAmount',
        )
        await assert.isRejected(
          transfer(user, chip, options[1], disputedAmount - 1n),
          'WageringPeriodHasAlreadyEnded',
        )
      }
    })

    it('Successful dispute', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)
      }
    })

    it('Expired dispute', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 8n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)
      }
    })

    it('Disputed records', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        const [
          userDisputedAmount,
          hackerDisputedAmount,
        ] = await dispute(chip, [
          [user, 8n],
          [hacker, 1n],
        ], Bet)

        assert.equal(
          await Bet.read.disputedAmount(),
          userDisputedAmount + hackerDisputedAmount,
        )
        assert.equal(
          await Bet.read.disputedAmount([user.account.address]),
          userDisputedAmount,
        )
        assert.equal(
          await Bet.read.disputedAmount([hacker.account.address]),
          hackerDisputedAmount,
        )
        assert.deepEqual(await Bet.read.disputedRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userDisputedAmount,
          },
          {
            account: getAddress(hacker.account.address),
            amount: hackerDisputedAmount,
          },
        ])

        // Cancel the dispute
        await checkBalance(
          async () => {
            await transfer(hacker, chip, Bet.address, 0n)
          },
          [
            [hacker.account.address, chip, hackerDisputedAmount],
          ],
        )
        assert.equal(
          await Bet.read.disputedAmount([hacker.account.address]),
          0n,
        )
        assert.deepEqual(await Bet.read.disputedRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userDisputedAmount,
          },
        ])
      }
    })
  })

  describe('Arbitration', () => {
    it('Successful arbitration', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(BetVotingEscrow.address, [
          [owner, options[0], 1n],
          [user, options[1], 1n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)
      }
    })

    it('Successful arbitration, and cancellation', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(BetVotingEscrow.address, [
          [owner, options[0], 1n],
          [user, Bet.address, 1n],
          [hacker, Bet.address, 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }
    })

    it('Invalid arbitration', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(BetVotingEscrow.address, [
          [owner, options[0], 1n],
          [user, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }
    })

    it('Expired arbitration', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }
    })

    it('Confirmed records', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(BetVotingEscrow.address, [
          [owner, options[0], 1n],
          [user, options[1], 1n],
          [hacker, options[1], 1n],
        ])
        const BetOption1 = await getBetOption(options[0])
        const BetOption2 = await getBetOption(options[1])

        const ownerArbitratedAmount = await BetVotingEscrow.read.balanceOf([owner.account.address, true])
        const userArbitratedAmount = await BetVotingEscrow.read.balanceOf([user.account.address, true])
        const hackerArbitratedAmount = await BetVotingEscrow.read.balanceOf([hacker.account.address, true])
        assert.equal(await BetOption1.read.arbitratedAmount(), ownerArbitratedAmount)
        assert.equal(
          await BetOption2.read.arbitratedAmount(),
          userArbitratedAmount + hackerArbitratedAmount,
        )
        assert.equal(
          await BetOption1.read.arbitratedAmount([owner.account.address]),
          ownerArbitratedAmount,
        )
        assert.equal(
          await BetOption2.read.arbitratedAmount([user.account.address]),
          userArbitratedAmount,
        )
        assert.equal(
          await BetOption2.read.arbitratedAmount([hacker.account.address]),
          hackerArbitratedAmount,
        )
        assert.deepEqual(await BetOption1.read.arbitratedRecords(), [
          {
            account: getAddress(owner.account.address),
            amount: ownerArbitratedAmount,
          },
        ])
        assert.deepEqual(await BetOption2.read.arbitratedRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userArbitratedAmount,
          },
          {
            account: getAddress(hacker.account.address),
            amount: hackerArbitratedAmount,
          },
        ])

        // Cancel the arbitration
        await checkBalance(
          async () => {
            await transfer(hacker, BetVotingEscrow.address, BetOption2.address, 0n)
          },
          [
            [hacker.account.address, BetVotingEscrow.address, 0n],
          ],
        )
        assert.equal(
          await BetOption2.read.arbitratedAmount([hacker.account.address]),
          0n,
        )
        assert.deepEqual(await BetOption2.read.arbitratedRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userArbitratedAmount,
          },
        ])
      }
    })
  })

  describe('Release', () => {
    it('Release by transfer to the Bet contract', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)

        await assert.isRejected(
          transfer(hacker, chip, Bet.address, 1n),
          'CannotReceive',
        )

        await checkBalance(
          async () => {
            await transfer(hacker, chip, Bet.address, 0n)
          },
          [
            [user.account.address, chip, creatorReward],
            [hacker.account.address, chip, 0n],
          ],
        )
        assert.equal(await Bet.read.status(), BetStatus.CLOSED)
        assert.equal(await Bet.read.released(), true)
      }
    })

    it('Release by transfer to the BetOption contract', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)

        await assert.isRejected(
          transfer(hacker, chip, options[1], 1n),
          'CannotReceive',
        )

        await checkBalance(
          async () => {
            await transfer(hacker, chip, options[1], 0n)
          },
          [
            [user.account.address, chip, creatorReward],
            [hacker.account.address, chip, 0n],
          ],
        )
        assert.equal(await Bet.read.status(), BetStatus.CLOSED)
        assert.equal(await Bet.read.released(), true)
      }
    })

    it('Release when cancelled', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        const [
          ownerWageredAmount,
          userWageredAmount,
          hackerWageredAmount,
        ] = await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        const [
          ownerDecidedAmount,
          userDecidedAmount,
          hackerDecidedAmount,
        ] = await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)

        await checkBalance(
          async () => {
            await checkVoteLevel(
              BetVotingEscrow,
              async () => {
                await Bet.write.release({ account: hacker.account })
              },
              [
                [owner.account.address, 0n],
                [user.account.address, 0n],
                [hacker.account.address, 0n],
              ],
            )
          },
          [
            [Bet.address, chip, 0n],
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, ownerWageredAmount],
            [user.account.address, chip, userWageredAmount],
            [hacker.account.address, chip, hackerWageredAmount],
            [owner.account.address, BetVotingEscrow.address, ownerDecidedAmount],
            [user.account.address, BetVotingEscrow.address, userDecidedAmount],
            [hacker.account.address, BetVotingEscrow.address, hackerDecidedAmount],
          ],
        )

        await isBetClosed(Bet, chip)
        await isCorrectStakeReward(
          BetVotingEscrow,
          GovTokenStaking,
          chip,
          [
            owner.account.address,
            user.account.address,
            hacker.account.address,
          ],
          0n,
        )
      }
    })

    it('Release when cancelled after dispute occurred', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        const [
          ownerWageredAmount,
          userWageredAmount,
          hackerWageredAmount,
        ] = await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        const [
          ownerDecidedAmount,
          userDecidedAmount,
          hackerDecidedAmount,
        ] = await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        const [
          userDisputedAmount,
          hackerDisputedAmount,
        ] = await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(BetVotingEscrow.address, [
          [owner, options[0], 1n],
          [user, Bet.address, 1n],
          [hacker, Bet.address, 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)

        await checkBalance(
          async () => {
            await checkVoteLevel(
              BetVotingEscrow,
              async () => {
                await Bet.write.release({ account: hacker.account })
              },
              [
                [owner.account.address, 0n],
                [user.account.address, 0n],
                [hacker.account.address, 0n],
              ],
            )
          },
          [
            [Bet.address, chip, -(userDisputedAmount + hackerDisputedAmount)],
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, ownerWageredAmount],
            [user.account.address, chip, userWageredAmount + userDisputedAmount],
            [hacker.account.address, chip, hackerWageredAmount + hackerDisputedAmount],
            [owner.account.address, BetVotingEscrow.address, ownerDecidedAmount],
            [user.account.address, BetVotingEscrow.address, userDecidedAmount],
            [hacker.account.address, BetVotingEscrow.address, hackerDecidedAmount],
          ],
        )

        await isBetClosed(Bet, chip)
        await isCorrectStakeReward(
          BetVotingEscrow,
          GovTokenStaking,
          chip,
          [
            owner.account.address,
            user.account.address,
            hacker.account.address,
          ],
          0n,
        )
      }
    })

    it('Release when confirmed', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        const [
          ownerWageredAmount,
          userWageredAmount,
          hackerWageredAmount,
        ] = await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        const [
          ownerDecidedAmount,
          userDecidedAmount,
          hackerDecidedAmount,
        ] = await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        const [
          userDisputedAmount,
          hackerDisputedAmount,
        ] = await dispute(chip, [
          [user, 8n],
          [hacker, 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)
        const winnerReward = await getWinnerReward(Bet, owner.account.address)
        const deciderReward = await getDeciderReward(Bet, owner.account.address)

        await checkBalance(
          async () => {
            await checkVoteLevel(
              BetVotingEscrow,
              async () => {
                await Bet.write.release({ account: hacker.account })
              },
              [
                [owner.account.address, 1n],
                [user.account.address, 0n],
                [hacker.account.address, 0n],
              ],
            )
          },
          [
            [Bet.address, chip, -(userDisputedAmount + hackerDisputedAmount)],
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, winnerReward + deciderReward],
            [user.account.address, chip, creatorReward + userDisputedAmount],
            [hacker.account.address, chip, hackerDisputedAmount],
            [owner.account.address, BetVotingEscrow.address, ownerDecidedAmount],
            [user.account.address, BetVotingEscrow.address, userDecidedAmount],
            [hacker.account.address, BetVotingEscrow.address, hackerDecidedAmount],
          ],
        )

        await isBetClosed(Bet, chip)
        await isCorrectStakeReward(
          BetVotingEscrow,
          GovTokenStaking,
          chip,
          [
            owner.account.address,
            user.account.address,
            hacker.account.address,
          ],
          (
            ownerWageredAmount
            + userWageredAmount
            + hackerWageredAmount
          ) - (
            creatorReward
            + winnerReward
            + deciderReward
          ),
        )
      }
    })

    it('Release when confirmed, and no one wagered on the winning option', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        const [
          ownerWageredAmount,
          userWageredAmount,
          hackerWageredAmount,
        ] = await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        const [
          ownerDecidedAmount,
          userDecidedAmount,
          hackerDecidedAmount,
        ] = await decide(BetVotingEscrow.address, [
          [owner, options[2], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)
        const deciderReward = await getDeciderReward(Bet, owner.account.address)

        await checkBalance(
          async () => {
            await checkVoteLevel(
              BetVotingEscrow,
              async () => {
                await Bet.write.release({ account: hacker.account })
              },
              [
                [owner.account.address, 1n],
                [user.account.address, 0n],
                [hacker.account.address, 0n],
              ],
            )
          },
          [
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, deciderReward],
            [user.account.address, chip, creatorReward],
            [hacker.account.address, chip, 0n],
            [owner.account.address, BetVotingEscrow.address, ownerDecidedAmount],
            [user.account.address, BetVotingEscrow.address, userDecidedAmount],
            [hacker.account.address, BetVotingEscrow.address, hackerDecidedAmount],
          ],
        )

        await isBetClosed(Bet, chip)
        await isCorrectStakeReward(
          BetVotingEscrow,
          GovTokenStaking,
          chip,
          [
            owner.account.address,
            user.account.address,
            hacker.account.address,
          ],
          (
            ownerWageredAmount
            + userWageredAmount
            + hackerWageredAmount
          ) - (
            creatorReward
            + deciderReward
          ),
        )
      }
    })

    it('Release when confirmed after dispute occurred, and no one decided on the winning option', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        GovToken,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        const [
          ownerWageredAmount,
          userWageredAmount,
          hackerWageredAmount,
        ] = await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        const [
          ownerDecidedAmount,
          userDecidedAmount,
          hackerDecidedAmount,
        ] = await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        const [
          userDisputedAmount,
          hackerDisputedAmount,
        ] = await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(BetVotingEscrow.address, [
          [owner, options[0], 1n],
          [user, options[2], 1n],
          [hacker, options[2], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)
        const userConfiscatedVoteReward = await getConfiscatedVoteReward(Bet, user.account.address)
        const hackerConfiscatedVoteReward = await getConfiscatedVoteReward(Bet, hacker.account.address)
        assert.equal(
          ownerDecidedAmount,
          userConfiscatedVoteReward + hackerConfiscatedVoteReward,
        )

        await checkBalance(
          async () => {
            await checkVoteLevel(
              BetVotingEscrow,
              async () => {
                await Bet.write.release({ account: hacker.account })
              },
              [
                [owner.account.address, 0n],
                [user.account.address, 0n],
                [hacker.account.address, 0n],
              ],
            )
          },
          [
            [Bet.address, chip, -(userDisputedAmount + hackerDisputedAmount)],
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, 0n],
            [user.account.address, chip, creatorReward + userDisputedAmount],
            [hacker.account.address, chip, hackerDisputedAmount],
            [owner.account.address, BetVotingEscrow.address, 0n],
            [user.account.address, BetVotingEscrow.address, userDecidedAmount],
            [hacker.account.address, BetVotingEscrow.address, hackerDecidedAmount],
            [owner.account.address, GovToken.address, 0n],
            [user.account.address, GovToken.address, userConfiscatedVoteReward],
            [hacker.account.address, GovToken.address, hackerConfiscatedVoteReward],
          ],
        )

        await isBetClosed(Bet, chip)
        await isCorrectStakeReward(
          BetVotingEscrow,
          GovTokenStaking,
          chip,
          [
            owner.account.address,
            user.account.address,
            hacker.account.address,
          ],
          (
            ownerWageredAmount
            + userWageredAmount
            + hackerWageredAmount
          ) - creatorReward,
        )
      }
    })

    it('Release when confirmed after dispute occurred, and punish disputer', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        const [
          ownerWageredAmount,
          userWageredAmount,
          hackerWageredAmount,
        ] = await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        const [
          ownerDecidedAmount,
          userDecidedAmount,
          hackerDecidedAmount,
        ] = await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 3n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        const [
          ownerDisputedAmount,
        ] = await dispute(chip, [
          [owner, 10n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(BetVotingEscrow.address, [
          [owner, options[0], 1n],
          [user, options[1], 1n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)
        const userWinnerReward = await getWinnerReward(Bet, user.account.address)
        const hackerWinnerReward = await getWinnerReward(Bet, hacker.account.address)
        const userDeciderReward = await getDeciderReward(Bet, user.account.address)
        const hackerDeciderReward = await getDeciderReward(Bet, hacker.account.address)
        const userConfiscatedChipReward = await getConfiscatedChipReward(Bet, user.account.address)
        const hackerConfiscatedChipReward = await getConfiscatedChipReward(Bet, hacker.account.address)
        assert.equal(
          ownerDisputedAmount,
          userConfiscatedChipReward + hackerConfiscatedChipReward,
        )

        await checkBalance(
          async () => {
            await checkVoteLevel(
              BetVotingEscrow,
              async () => {
                await Bet.write.release({ account: hacker.account })
              },
              [
                [owner.account.address, 0n],
                [user.account.address, 1n],
                [hacker.account.address, 1n],
              ],
            )
          },
          [
            [Bet.address, chip, -ownerDisputedAmount],
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, 0n],
            [user.account.address, chip, creatorReward + userWinnerReward + userDeciderReward + userConfiscatedChipReward],
            [hacker.account.address, chip, hackerWinnerReward + hackerDeciderReward + hackerConfiscatedChipReward],
            [owner.account.address, BetVotingEscrow.address, ownerDecidedAmount],
            [user.account.address, BetVotingEscrow.address, userDecidedAmount],
            [hacker.account.address, BetVotingEscrow.address, hackerDecidedAmount],
          ],
        )

        await isBetClosed(Bet, chip)
        await isCorrectStakeReward(
          BetVotingEscrow,
          GovTokenStaking,
          chip,
          [
            owner.account.address,
            user.account.address,
            hacker.account.address,
          ],
          (
            ownerWageredAmount
            + userWageredAmount
            + hackerWageredAmount
          ) - (
            creatorReward
            + userWinnerReward
            + userDeciderReward
            + hackerWinnerReward
            + hackerDeciderReward
          ),
        )
      }
    })

    it('Release when confirmed after dispute occurred, and punish decider', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        GovToken,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        const [
          ownerWageredAmount,
          userWageredAmount,
          hackerWageredAmount,
        ] = await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        const [
          ownerDecidedAmount,
          userDecidedAmount,
          hackerDecidedAmount,
        ] = await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        const [
          userDisputedAmount,
          hackerDisputedAmount,
        ] = await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(BetVotingEscrow.address, [
          [owner, options[0], 1n],
          [user, options[1], 1n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)
        const userWinnerReward = await getWinnerReward(Bet, user.account.address)
        const hackerWinnerReward = await getWinnerReward(Bet, hacker.account.address)
        const userDeciderReward = await getDeciderReward(Bet, user.account.address)
        const hackerDeciderReward = await getDeciderReward(Bet, hacker.account.address)
        const userConfiscatedVoteReward = await getConfiscatedVoteReward(Bet, user.account.address)
        const hackerConfiscatedVoteReward = await getConfiscatedVoteReward(Bet, hacker.account.address)
        assert.equal(
          ownerDecidedAmount,
          userConfiscatedVoteReward + hackerConfiscatedVoteReward,
        )

        await checkBalance(
          async () => {
            await checkVoteLevel(
              BetVotingEscrow,
              async () => {
                await Bet.write.release({ account: hacker.account })
              },
              [
                [owner.account.address, 0n],
                [user.account.address, 1n],
                [hacker.account.address, 1n],
              ],
            )
          },
          [
            [Bet.address, chip, -(userDisputedAmount + hackerDisputedAmount)],
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, 0n],
            [user.account.address, chip, creatorReward + userWinnerReward + userDeciderReward + userDisputedAmount],
            [hacker.account.address, chip, hackerWinnerReward + hackerDeciderReward + hackerDisputedAmount],
            [owner.account.address, BetVotingEscrow.address, 0n],
            [user.account.address, BetVotingEscrow.address, userDecidedAmount],
            [hacker.account.address, BetVotingEscrow.address, hackerDecidedAmount],
            [owner.account.address, GovToken.address, 0n],
            [user.account.address, GovToken.address, userConfiscatedVoteReward],
            [hacker.account.address, GovToken.address, hackerConfiscatedVoteReward],
          ],
        )

        await isBetClosed(Bet, chip)
        await isCorrectStakeReward(
          BetVotingEscrow,
          GovTokenStaking,
          chip,
          [
            owner.account.address,
            user.account.address,
            hacker.account.address,
          ],
          (
            ownerWageredAmount
            + userWageredAmount
            + hackerWageredAmount
          ) - (
            creatorReward
            + userWinnerReward
            + userDeciderReward
            + hackerWinnerReward
            + hackerDeciderReward
          ),
        )
      }
    })

    it('Invalid release', async () => {
      const {
        BetChip,
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const useChipERC20 = isAddressEqual(chip, BetChip.address)
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          useChipERC20,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.DECIDING)

        await decide(BetVotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await assert.isRejected(
          Bet.write.release({ account: hacker.account }),
          'BetHasNotEndedYet',
        )

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        await transfer(user, chip, Bet.address, 0n)
        await assert.isRejected(
          Bet.write.release({ account: hacker.account }),
          'BetHasBeenReleased',
        )
      }
    })

    it('Contract attack on release', async () => {
      const {
        BetVotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const Bet = await createBet(
        user,
        BetManager,
        BetDetails,
        WEEK,
        DAY3,
      )
      const options = await Bet.read.options()

      await assert.isRejected(
        viem.deployContract(
          'AttackContract' as never,
          [options[0]],
          { value: parseEther('1') },
        ),
        'TransferFailed',
      )

      await wager(zeroAddress, [
        [owner, options[0], 2n],
        [user, options[1], 9n],
        [hacker, options[1], 1n],
      ], Bet)
      await time.increaseTo(await Bet.read.statusDeadline() + 1n)
      assert.equal(await Bet.read.status(), BetStatus.DECIDING)

      await decide(BetVotingEscrow.address, [
        [owner, options[0], 5n],
        [user, options[1], 3n],
        [hacker, options[1], 1n],
      ])
      await time.increaseTo(await Bet.read.statusDeadline() + 1n)
      assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

      await assert.isRejected(
        viem.deployContract(
          'AttackContract' as never,
          [Bet.address],
          { value: parseEther('1') },
        ),
        'TransferFailed',
      )

      assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

      await time.increaseTo(await Bet.read.statusDeadline() + 1n)
      assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

      await Bet.write.release({ account: hacker.account })
      assert.equal(await Bet.read.status(), BetStatus.CLOSED)
    })
  })
})
