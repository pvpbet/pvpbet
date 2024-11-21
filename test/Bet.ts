import { loadFixture, time } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  encodeFunctionData,
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
  getBetByHash,
  getBetOption,
  getConfiscatedChipReward,
  getConfiscatedVoteReward,
  getCreatorReward,
  getVerifierReward,
  getWinnerReward,
  decide,
  wager,
} from './common/bet'
import {
  buyChip,
  createBetChip,
  deployBetChipManager,
} from './common/chip'
import {
  UnlockWaitingPeriod,
  deployGovTokenStaking,
  stake,
  unstake,
} from './common/staking'
import { deployVotingEscrow } from './common/vote'
import {
  checkBalance,
  isBetClosed,
  isCorrectStakeReward,
} from './asserts'
import type { Address } from 'viem'
import type { ContractTypes } from '../types'

const DAY = 24n * 3600n
const DAY3 = 3n * DAY
const WEEK = 7n * DAY

describe('Bet', () => {
  type DeployFixtureReturnType = Awaited<ReturnType<typeof loadFixture<ReturnType<typeof deployFixture>>>>
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const testTokens = await deployTestTokens()
    await claimTestTokens(owner, testTokens)
    await claimTestTokens(user, testTokens)
    await claimTestTokens(hacker, testTokens)

    const { USDC } = testTokens
    const BetChipManager = await deployBetChipManager()
    const BetChip = await createBetChip(owner, BetChipManager, USDC.address)
    const VotingEscrow = await deployVotingEscrow()
    const GovToken = await deployGovToken()
    const GovTokenStaking = await deployGovTokenStaking(VotingEscrow.address, GovToken.address, BetChip.address)
    const BetManager = await deployBetManager(BetChipManager.address, VotingEscrow.address, GovToken.address)
    const BetConfigurator = await viem.getContractAt('BetConfigurator', await BetManager.read.betConfigurator())

    await VotingEscrow.write.setGovTokenStaking([GovTokenStaking.address])
    await BetConfigurator.write.setChipMinValue([BetChip.address, parseUnits('1', 6)])
    await BetConfigurator.write.setMinWageredTotalAmount([BetChip.address, parseUnits('1000', 6)])
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
          UnlockWaitingPeriod.WEEK,
          parseUnits('200000', 18),
        )
        await stake(
          wallet,
          GovToken,
          GovTokenStaking,
          UnlockWaitingPeriod.WEEK12,
          parseUnits('200000', 18),
        )
        await buyChip(
          wallet,
          BetChip,
          USDC.address,
          parseUnits('100000', await USDC.read.decimals()),
        )
      }),
    )

    return {
      ...testTokens,
      BetChip,
      VotingEscrow,
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
        VotingEscrow,
        BetManager,
        user,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const currentTime = BigInt(await time.latest())

        await assert.isRejected(
          Bet.write.initialize([
            '2.0.0',
            {
              chipMinValue: 0n,
              voteMinValue: 0n,
              minWageredTotalAmount: 0n,
              minVerifiedTotalAmount: 0n,
              minArbitratedTotalAmount: 0n,
              announcementPeriodDuration: 0n,
              arbitratingPeriodDuration: 0n,
              singleOptionMaxAmountRatio: 0n,
              confirmDisputeAmountRatio: 0n,
              protocolRewardRatio: 0n,
              creatorRewardRatio: 0n,
              verifierRewardRatio: 0n,
              countPerRelease: 0n,
              countPerPenalize: 0n,
            },
            BetDetails,
            WEEK,
            DAY3,
            zeroAddress,
            zeroAddress,
            zeroAddress,
            zeroAddress,
            zeroAddress,
            zeroAddress,
          ], { account: user.account }),
          'InvalidInitialization',
        )

        assert.equal(await Bet.read.isBet(), true)
        assert.equal(await Bet.read.bet(), Bet.address)
        assert.equal(await Bet.read.chip(), chip)
        assert.equal(await Bet.read.vote(), VotingEscrow.address)
        assert.equal(await Bet.read.creator(), getAddress(user.account.address))
        assert.equal(await Bet.read.wageringPeriodDeadline(), currentTime + WEEK)
        assert.equal(await Bet.read.verifyingPeriodDeadline(), currentTime + WEEK + DAY3)
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
          assert.equal(await BetOption.read.vote(), VotingEscrow.address)
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        const wageredAmount = await Bet.read.chipMinValue()
        await assert.isRejected(
          transfer(user, chip, Bet.address, wageredAmount - 1n),
          'InvalidAmount',
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
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
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)
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
        {
          const Bet = await createBet(
            user,
            BetManager,
            BetDetails,
            WEEK,
            DAY3,
            chip,
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
            chip,
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
            chip,
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
        {
          const Bet = await createBet(
            user,
            BetManager,
            BetDetails,
            WEEK,
            DAY3,
            chip,
          )
          const options = await Bet.read.options()
          await wager(chip, [
            [owner, options[0], 2n],
            [user, options[1], 9n],
            [hacker, options[1], 1n],
          ], Bet)
          await time.increaseTo(await Bet.read.statusDeadline() + 1n)
          assert.equal(await Bet.read.status(), BetStatus.VERIFYING)
          await assert.isRejected(
            transfer(user, chip, Bet.address, 1n),
            'InvalidAmount',
          )
          await assert.isRejected(
            transfer(user, chip, options[0], 1n),
            'InvalidAmount',
          )
        }

        {
          const Bet = await createBet(
            user,
            BetManager,
            BetDetails,
            WEEK,
            DAY3,
            chip,
          )
          const options = await Bet.read.options()
          await time.increaseTo(await Bet.read.statusDeadline() + 1n)
          assert.equal(await Bet.read.status(), BetStatus.CLOSED)
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
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 6n],
          [hacker, options[1], 1n],
        ], Bet)
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
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
        assert.equal(
          await BetOption1.read.wageredAmount(),
          ownerWageredAmount,
        )
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

  describe('Verification', () => {
    it('Preventing dust attacks', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        const verifiedAmount = await Bet.read.voteMinValue()
        await assert.isRejected(
          transfer(user, VotingEscrow.address, Bet.address, verifiedAmount - 1n),
          'InvalidStatus',
        )
        await assert.isRejected(
          transfer(user, VotingEscrow.address, options[1], verifiedAmount - 1n),
          'InvalidAmount',
        )
      }
    })

    it('Successful verification', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)
      }
    })

    it('Invalid verification', async () => {
      const {
        BetChip,
        VotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      // Insufficient verifying ratio
      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }

      // Insufficient verifying amount
      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }
    })

    it('Failed verification', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.WAGERING)

        const verifiedAmount = parseUnits('1000', 18)
        await assert.isRejected(
          transfer(user, VotingEscrow.address, options[1], verifiedAmount),
          'InvalidStatus',
        )

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await assert.isRejected(
          transfer(user, VotingEscrow.address, options[1], verifiedAmount),
          'InvalidStatus',
        )
      }
    })

    it('Expired verification', async () => {
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }
    })

    it('Verified records', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        const [
          ownerVerifiedAmount,
          userVerifiedAmount,
          hackerVerifiedAmount,
        ] = await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        const BetOption1 = await getBetOption(options[0])
        const BetOption2 = await getBetOption(options[1])

        assert.equal(
          await Bet.read.verifiedTotalAmount(),
          ownerVerifiedAmount + userVerifiedAmount + hackerVerifiedAmount,
        )
        assert.equal(
          await BetOption1.read.verifiedAmount(),
          ownerVerifiedAmount,
        )
        assert.equal(
          await BetOption2.read.verifiedAmount(),
          userVerifiedAmount + hackerVerifiedAmount,
        )
        assert.equal(
          await BetOption1.read.verifiedAmount([owner.account.address]),
          ownerVerifiedAmount,
        )
        assert.equal(
          await BetOption2.read.verifiedAmount([user.account.address]),
          userVerifiedAmount,
        )
        assert.equal(
          await BetOption2.read.verifiedAmount([hacker.account.address]),
          hackerVerifiedAmount,
        )
        assert.deepEqual(await BetOption1.read.verifiedRecords(), [
          {
            account: getAddress(owner.account.address),
            amount: ownerVerifiedAmount,
          },
        ])
        assert.deepEqual(await BetOption2.read.verifiedRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userVerifiedAmount,
          },
          {
            account: getAddress(hacker.account.address),
            amount: hackerVerifiedAmount,
          },
        ])

        // Cancel the verification
        await checkBalance(
          async () => {
            await transfer(hacker, VotingEscrow.address, BetOption2.address, 0n)
          },
          [
            [hacker.account.address, VotingEscrow.address, hackerVerifiedAmount],
          ],
        )
        assert.equal(
          await BetOption2.read.verifiedAmount([hacker.account.address]),
          0n,
        )
        assert.deepEqual(await BetOption2.read.verifiedRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userVerifiedAmount,
          },
        ])
      }
    })
  })

  describe('Announcement', () => {
    it('Expired announcement', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
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
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        const disputedAmount = await Bet.read.chipMinValue()
        await assert.isRejected(
          transfer(user, chip, Bet.address, disputedAmount - 1n),
          'InvalidAmount',
        )
        await assert.isRejected(
          transfer(user, chip, options[1], disputedAmount - 1n),
          'InvalidAmount',
        )
      }
    })

    it('Successful dispute', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)
      }
    })

    it('Invalid dispute', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
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

    it('Failed dispute', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.WAGERING)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)

        await assert.isRejected(
          dispute(chip, [
            [user, 8n],
          ], Bet),
          'AnnouncementPeriodHasNotStartedYet',
        )

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        await assert.isRejected(
          dispute(chip, [
            [user, 8n],
          ], Bet),
          'CannotReceive',
        )
      }
    })

    it('Disputed records', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
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
          await Bet.read.disputedTotalAmount(),
          userDisputedAmount + hackerDisputedAmount,
        )
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
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(VotingEscrow.address, [
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
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(VotingEscrow.address, [
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
        VotingEscrow,
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

      // Insufficient verifying ratio
      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(VotingEscrow.address, [
          [owner, options[0], 1n],
          [user, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)
      }

      // Insufficient verifying amount
      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        const stakedAmount = (await GovTokenStaking.read.stakedAmount([owner.account.address, UnlockWaitingPeriod.WEEK12])) as bigint
        const minArbitratedTotalAmount = (await Bet.read.minArbitratedTotalAmount()) as bigint
        await unstake(owner, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakedAmount - (minArbitratedTotalAmount - 1n))

        await arbitrate(VotingEscrow.address, [
          [owner, options[0], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)

        await GovTokenStaking.write.restake([0n], { account: owner.account })
      }
    })

    it('Expired arbitration', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
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

    it('Arbitrated records', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await dispute(chip, [
          [user, 9n],
          [hacker, 1n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(VotingEscrow.address, [
          [owner, Bet.address, 1n],
          [user, options[1], 1n],
          [hacker, options[1], 1n],
        ])
        const BetOption = await getBetOption(options[1])

        const ownerArbitratedAmount = (await GovTokenStaking.read.stakedAmount([owner.account.address, UnlockWaitingPeriod.WEEK12])) as bigint
        const userArbitratedAmount = (await GovTokenStaking.read.stakedAmount([user.account.address, UnlockWaitingPeriod.WEEK12])) as bigint
        const hackerArbitratedAmount = (await GovTokenStaking.read.stakedAmount([hacker.account.address, UnlockWaitingPeriod.WEEK12])) as bigint
        assert.equal(
          await Bet.read.arbitratedTotalAmount(),
          ownerArbitratedAmount + userArbitratedAmount + hackerArbitratedAmount,
        )
        assert.equal(
          await Bet.read.arbitratedAmount(),
          ownerArbitratedAmount,
        )
        assert.equal(
          await BetOption.read.arbitratedAmount(),
          userArbitratedAmount + hackerArbitratedAmount,
        )
        assert.equal(
          await Bet.read.arbitratedAmount([owner.account.address]),
          ownerArbitratedAmount,
        )
        assert.equal(
          await BetOption.read.arbitratedAmount([user.account.address]),
          userArbitratedAmount,
        )
        assert.equal(
          await BetOption.read.arbitratedAmount([hacker.account.address]),
          hackerArbitratedAmount,
        )
        assert.deepEqual(await Bet.read.arbitratedRecords(), [
          {
            account: getAddress(owner.account.address),
            amount: ownerArbitratedAmount,
          },
        ])
        assert.deepEqual(await BetOption.read.arbitratedRecords(), [
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
            await transfer(hacker, VotingEscrow.address, BetOption.address, 0n)
          },
          [
            [hacker.account.address, VotingEscrow.address, 0n],
          ],
        )
        assert.equal(
          await BetOption.read.arbitratedAmount([hacker.account.address]),
          0n,
        )
        assert.deepEqual(await BetOption.read.arbitratedRecords(), [
          {
            account: getAddress(user.account.address),
            amount: userArbitratedAmount,
          },
        ])
      }
    })
  })

  describe('Release', () => {
    async function cancelled(
      release: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
    ) {
      const data = await loadFixture(deployFixture)
      const {
        BetChip,
        VotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = data

      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
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
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        const [
          ownerVerifiedAmount,
          userVerifiedAmount,
          hackerVerifiedAmount,
        ] = await decide(VotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)

        await checkBalance(
          async () => {
            await release(Bet, chip, data)
            await assert.isRejected(
              Bet.write.release({ account: owner.account }),
              'BetHasBeenReleased',
            )
            await assert.isRejected(
              Bet.write.penalize({ account: owner.account }),
              'NoTargetForPenalty',
            )
          },
          [
            [Bet.address, chip, 0n],
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, ownerWageredAmount],
            [user.account.address, chip, userWageredAmount],
            [hacker.account.address, chip, hackerWageredAmount],
            [owner.account.address, VotingEscrow.address, ownerVerifiedAmount],
            [user.account.address, VotingEscrow.address, userVerifiedAmount],
            [hacker.account.address, VotingEscrow.address, hackerVerifiedAmount],
          ],
        )

        await isCorrectStakeReward(
          GovTokenStaking,
          chip,
          [
            owner.account.address,
            user.account.address,
            hacker.account.address,
          ],
          0n,
        )

        await isBetClosed(Bet, chip)
      }
    }

    async function cancelledAfterDisputeOccurred(
      release: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
    ) {
      const data = await loadFixture(deployFixture)
      const {
        BetChip,
        VotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = data

      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
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
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        const [
          ownerVerifiedAmount,
          userVerifiedAmount,
          hackerVerifiedAmount,
        ] = await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
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

        await arbitrate(VotingEscrow.address, [
          [owner, options[0], 1n],
          [user, Bet.address, 1n],
          [hacker, Bet.address, 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CANCELLED)

        await checkBalance(
          async () => {
            await release(Bet, chip, data)
            await assert.isRejected(
              Bet.write.release({ account: owner.account }),
              'BetHasBeenReleased',
            )
            await assert.isRejected(
              Bet.write.penalize({ account: owner.account }),
              'NoTargetForPenalty',
            )
          },
          [
            [Bet.address, chip, -(userDisputedAmount + hackerDisputedAmount)],
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, ownerWageredAmount],
            [user.account.address, chip, userWageredAmount + userDisputedAmount],
            [hacker.account.address, chip, hackerWageredAmount + hackerDisputedAmount],
            [owner.account.address, VotingEscrow.address, ownerVerifiedAmount],
            [user.account.address, VotingEscrow.address, userVerifiedAmount],
            [hacker.account.address, VotingEscrow.address, hackerVerifiedAmount],
          ],
        )

        await isCorrectStakeReward(
          GovTokenStaking,
          chip,
          [
            owner.account.address,
            user.account.address,
            hacker.account.address,
          ],
          0n,
        )

        await isBetClosed(Bet, chip)
      }
    }

    async function confirmed(
      release: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
    ) {
      const data = await loadFixture(deployFixture)
      const {
        BetChip,
        VotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = data

      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
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
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        const [
          ownerVerifiedAmount,
          userVerifiedAmount,
          hackerVerifiedAmount,
        ] = await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
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
        const verifierReward = await getVerifierReward(Bet, owner.account.address)

        await checkBalance(
          async () => {
            await release(Bet, chip, data)
            await assert.isRejected(
              Bet.write.release({ account: owner.account }),
              'BetHasBeenReleased',
            )
            await assert.isRejected(
              Bet.write.penalize({ account: owner.account }),
              'NoTargetForPenalty',
            )
          },
          [
            [Bet.address, chip, -(userDisputedAmount + hackerDisputedAmount)],
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, winnerReward + verifierReward],
            [user.account.address, chip, creatorReward + userDisputedAmount],
            [hacker.account.address, chip, hackerDisputedAmount],
            [owner.account.address, VotingEscrow.address, ownerVerifiedAmount],
            [user.account.address, VotingEscrow.address, userVerifiedAmount],
            [hacker.account.address, VotingEscrow.address, hackerVerifiedAmount],
          ],
        )

        await isCorrectStakeReward(
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
            + verifierReward
          ),
        )

        await isBetClosed(Bet, chip)
      }
    }

    async function confirmedAndNoOneWageredOnTheWinningOption(
      release: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
    ) {
      const data = await loadFixture(deployFixture)
      const {
        BetChip,
        VotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = data

      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
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
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        const [
          ownerVerifiedAmount,
          userVerifiedAmount,
          hackerVerifiedAmount,
        ] = await decide(VotingEscrow.address, [
          [owner, options[2], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)
        const verifierReward = await getVerifierReward(Bet, owner.account.address)

        await checkBalance(
          async () => {
            await release(Bet, chip, data)
            await assert.isRejected(
              Bet.write.release({ account: owner.account }),
              'BetHasBeenReleased',
            )
            await assert.isRejected(
              Bet.write.penalize({ account: owner.account }),
              'NoTargetForPenalty',
            )
          },
          [
            [options[0], chip, -ownerWageredAmount],
            [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
            [owner.account.address, chip, verifierReward],
            [user.account.address, chip, creatorReward],
            [hacker.account.address, chip, 0n],
            [owner.account.address, VotingEscrow.address, ownerVerifiedAmount],
            [user.account.address, VotingEscrow.address, userVerifiedAmount],
            [hacker.account.address, VotingEscrow.address, hackerVerifiedAmount],
          ],
        )

        await isCorrectStakeReward(
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
            + verifierReward
          ),
        )

        await isBetClosed(Bet, chip)
      }
    }

    async function confirmedAfterDisputeOccurredAndNoOneVerifiedOnTheWinningOption(
      release: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
      penalize: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
      isPenalizeFirst?: boolean,
    ) {
      const data = await loadFixture(deployFixture)
      const {
        BetChip,
        VotingEscrow,
        BetManager,
        GovToken,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = data

      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
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
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        const [
          ownerVerifiedAmount,
          userVerifiedAmount,
          hackerVerifiedAmount,
        ] = await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
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

        await arbitrate(VotingEscrow.address, [
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
          ownerVerifiedAmount,
          userConfiscatedVoteReward + hackerConfiscatedVoteReward,
        )

        const handles = [
          async () => {
            await checkBalance(
              async () => {
                await release(Bet, chip, data)
                await assert.isRejected(
                  Bet.write.release([0n], { account: owner.account }),
                  'BetHasBeenReleased',
                )
              },
              [
                [Bet.address, chip, -(userDisputedAmount + hackerDisputedAmount)],
                [options[0], chip, -ownerWageredAmount],
                [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
                [owner.account.address, chip, 0n],
                [user.account.address, chip, creatorReward + userDisputedAmount],
                [hacker.account.address, chip, hackerDisputedAmount],
                [owner.account.address, VotingEscrow.address, 0n],
                [user.account.address, VotingEscrow.address, userVerifiedAmount],
                [hacker.account.address, VotingEscrow.address, hackerVerifiedAmount],
                [owner.account.address, GovToken.address, 0n],
                [user.account.address, GovToken.address, 0n],
                [hacker.account.address, GovToken.address, 0n],
              ],
            )

            await isCorrectStakeReward(
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
          },
          async () => {
            await checkBalance(
              async () => {
                await penalize(Bet, chip, data)
                await assert.isRejected(
                  Bet.write.penalize({ account: owner.account }),
                  'BetHasBeenPenalized',
                )
              },
              [
                [owner.account.address, GovToken.address, 0n],
                [user.account.address, GovToken.address, userConfiscatedVoteReward],
                [hacker.account.address, GovToken.address, hackerConfiscatedVoteReward],
              ],
            )
          },
        ]

        if (isPenalizeFirst) handles.reverse()
        for (const handle of handles) {
          await handle()
        }

        await isBetClosed(Bet, chip)
      }
    }

    async function confirmedAfterDisputeOccurredAndPunishDisputer(
      release: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
      penalize: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
      isPenalizeFirst?: boolean,
    ) {
      const data = await loadFixture(deployFixture)
      const {
        BetChip,
        VotingEscrow,
        BetManager,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = data

      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
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
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        const [
          ownerVerifiedAmount,
          userVerifiedAmount,
          hackerVerifiedAmount,
        ] = await decide(VotingEscrow.address, [
          [owner, options[0], 5n],
          [user, options[1], 3n],
          [hacker, options[1], 3n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

        const [
          ownerDisputedAmount,
        ] = await dispute(chip, [
          [owner, 10n],
        ], Bet)
        assert.equal(await Bet.read.status(), BetStatus.ARBITRATING)

        await arbitrate(VotingEscrow.address, [
          [owner, options[0], 1n],
          [user, options[1], 1n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)
        const userWinnerReward = await getWinnerReward(Bet, user.account.address)
        const hackerWinnerReward = await getWinnerReward(Bet, hacker.account.address)
        const userVerifierReward = await getVerifierReward(Bet, user.account.address)
        const hackerVerifierReward = await getVerifierReward(Bet, hacker.account.address)
        const userConfiscatedChipReward = await getConfiscatedChipReward(Bet, user.account.address)
        const hackerConfiscatedChipReward = await getConfiscatedChipReward(Bet, hacker.account.address)
        assert.equal(
          ownerDisputedAmount,
          userConfiscatedChipReward + hackerConfiscatedChipReward,
        )

        const handles = [
          async () => {
            await checkBalance(
              async () => {
                await release(Bet, chip, data)
                await assert.isRejected(
                  Bet.write.release([0n], { account: owner.account }),
                  'BetHasBeenReleased',
                )
              },
              [
                [Bet.address, chip, 0n],
                [options[0], chip, -ownerWageredAmount],
                [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
                [owner.account.address, chip, 0n],
                [user.account.address, chip, creatorReward + userWinnerReward + userVerifierReward],
                [hacker.account.address, chip, hackerWinnerReward + hackerVerifierReward],
                [owner.account.address, VotingEscrow.address, ownerVerifiedAmount],
                [user.account.address, VotingEscrow.address, userVerifiedAmount],
                [hacker.account.address, VotingEscrow.address, hackerVerifiedAmount],
              ],
            )

            await isCorrectStakeReward(
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
                + userVerifierReward
                + hackerWinnerReward
                + hackerVerifierReward
              ),
            )
          },
          async () => {
            await checkBalance(
              async () => {
                await penalize(Bet, chip, data)
                await assert.isRejected(
                  Bet.write.penalize({ account: owner.account }),
                  'BetHasBeenPenalized',
                )
              },
              [
                [Bet.address, chip, -ownerDisputedAmount],
                [options[0], chip, 0n],
                [options[1], chip, 0n],
                [owner.account.address, chip, 0n],
                [user.account.address, chip, userConfiscatedChipReward],
                [hacker.account.address, chip, hackerConfiscatedChipReward],
              ],
            )
          },
        ]

        if (isPenalizeFirst) handles.reverse()
        for (const handle of handles) {
          await handle()
        }

        await isBetClosed(Bet, chip)
      }
    }

    async function confirmedAfterDisputeOccurredAndPunishVerifier(
      release: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
      penalize: (
        Bet: ContractTypes['Bet'],
        chip: Address,
        data: DeployFixtureReturnType,
      ) => Promise<void>,
      isPenalizeFirst?: boolean,
    ) {
      const data = await loadFixture(deployFixture)
      const {
        BetChip,
        VotingEscrow,
        BetManager,
        GovToken,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = data

      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      for (const chip of chips) {
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
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
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        const [
          ownerVerifiedAmount,
          userVerifiedAmount,
          hackerVerifiedAmount,
        ] = await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
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

        await arbitrate(VotingEscrow.address, [
          [owner, options[0], 1n],
          [user, options[1], 1n],
          [hacker, options[1], 1n],
        ])
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

        const creatorReward = await getCreatorReward(Bet)
        const userWinnerReward = await getWinnerReward(Bet, user.account.address)
        const hackerWinnerReward = await getWinnerReward(Bet, hacker.account.address)
        const userVerifierReward = await getVerifierReward(Bet, user.account.address)
        const hackerVerifierReward = await getVerifierReward(Bet, hacker.account.address)
        const userConfiscatedVoteReward = await getConfiscatedVoteReward(Bet, user.account.address)
        const hackerConfiscatedVoteReward = await getConfiscatedVoteReward(Bet, hacker.account.address)
        assert.equal(
          ownerVerifiedAmount,
          userConfiscatedVoteReward + hackerConfiscatedVoteReward,
        )

        const handles = [
          async () => {
            await checkBalance(
              async () => {
                await release(Bet, chip, data)
                await assert.isRejected(
                  Bet.write.release([0n], { account: owner.account }),
                  'BetHasBeenReleased',
                )
              },
              [
                [Bet.address, chip, -(userDisputedAmount + hackerDisputedAmount)],
                [options[0], chip, -ownerWageredAmount],
                [options[1], chip, -(userWageredAmount + hackerWageredAmount)],
                [owner.account.address, chip, 0n],
                [user.account.address, chip, creatorReward + userWinnerReward + userVerifierReward + userDisputedAmount],
                [hacker.account.address, chip, hackerWinnerReward + hackerVerifierReward + hackerDisputedAmount],
                [owner.account.address, VotingEscrow.address, 0n],
                [user.account.address, VotingEscrow.address, userVerifiedAmount],
                [hacker.account.address, VotingEscrow.address, hackerVerifiedAmount],
              ],
            )

            await isCorrectStakeReward(
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
                + userVerifierReward
                + hackerWinnerReward
                + hackerVerifierReward
              ),
            )
          },
          async () => {
            await checkBalance(
              async () => {
                await penalize(Bet, chip, data)
                await assert.isRejected(
                  Bet.write.penalize({ account: owner.account }),
                  'BetHasBeenPenalized',
                )
              },
              [
                [owner.account.address, GovToken.address, 0n],
                [user.account.address, GovToken.address, userConfiscatedVoteReward],
                [hacker.account.address, GovToken.address, hackerConfiscatedVoteReward],
              ],
            )
          },
        ]

        if (isPenalizeFirst) handles.reverse()
        for (const handle of handles) {
          await handle()
        }

        await isBetClosed(Bet, chip)
      }
    }

    it('Release by transfer to the Bet contract', async () => {
      await cancelled(async (Bet, chip, { hacker }) => {
        await assert.isRejected(
          transfer(hacker, chip, Bet.address, 1n),
          'CannotReceive',
        )
        await transfer(hacker, chip, Bet.address, 0n)
      })

      await confirmed(async (Bet, chip, { hacker }) => {
        await assert.isRejected(
          transfer(hacker, chip, Bet.address, 1n),
          'CannotReceive',
        )
        await transfer(hacker, chip, Bet.address, 0n)
      })
    })

    it('Release by transfer to the BetOption contract', async () => {
      await cancelled(async (Bet, chip, { hacker }) => {
        const options = await Bet.read.options()
        await assert.isRejected(
          transfer(hacker, chip, options[1], 1n),
          'CannotReceive',
        )
        await transfer(hacker, chip, options[1], 0n)
      })

      await confirmed(async (Bet, chip, { hacker }) => {
        const options = await Bet.read.options()
        await assert.isRejected(
          transfer(hacker, chip, options[1], 1n),
          'CannotReceive',
        )
        await transfer(hacker, chip, options[1], 0n)
      })
    })

    it('Release when cancelled', async () => {
      await cancelled(async (Bet, chip, { hacker }) => {
        await Bet.write.release({ account: hacker.account })
      })

      // Step-by-step release
      await cancelled(async (Bet, chip, { hacker }) => {
        const [done, total] = await Bet.read.releasedProgress()
        assert.equal(done, 0n)
        for (let i = 0; i < Number(total); i++) {
          await Bet.write.release([1n], { account: hacker.account })
        }
        assert.deepEqual(await Bet.read.releasedProgress(), [total, total])
      })
    })

    it('Release when cancelled after dispute occurred', async () => {
      await cancelledAfterDisputeOccurred(async (Bet, chip, { hacker }) => {
        await Bet.write.release({ account: hacker.account })
      })

      // Step-by-step release
      await cancelledAfterDisputeOccurred(async (Bet, chip, { hacker }) => {
        const [done, total] = await Bet.read.releasedProgress()
        assert.equal(done, 0n)
        for (let i = 0; i < Number(total); i++) {
          await Bet.write.release([1n], { account: hacker.account })
        }
        assert.deepEqual(await Bet.read.releasedProgress(), [total, total])
      })
    })

    it('Release when confirmed', async () => {
      await confirmed(async (Bet, chip, { hacker }) => {
        await Bet.write.release({ account: hacker.account })
      })

      // Step-by-step release
      await confirmed(async (Bet, chip, { hacker }) => {
        const [done, total] = await Bet.read.releasedProgress()
        assert.equal(done, 0n)
        for (let i = 0; i < Number(total); i++) {
          await Bet.write.release([1n], { account: hacker.account })
        }
        assert.deepEqual(await Bet.read.releasedProgress(), [total, total])
      })
    })

    it('Release when confirmed, and no one wagered on the winning option', async () => {
      await confirmedAndNoOneWageredOnTheWinningOption(async (Bet, chip, { hacker }) => {
        await Bet.write.release({ account: hacker.account })
      })

      // Step-by-step release
      await confirmedAndNoOneWageredOnTheWinningOption(async (Bet, chip, { hacker }) => {
        const [done, total] = await Bet.read.releasedProgress()
        assert.equal(done, 0n)
        for (let i = 0; i < Number(total); i++) {
          await Bet.write.release([1n], { account: hacker.account })
        }
        assert.deepEqual(await Bet.read.releasedProgress(), [total, total])
      })
    })

    it('Release when confirmed after dispute occurred, and no one verified on the winning option', async () => {
      for (const isPenalizeFirst of [false, true]) {
        await confirmedAfterDisputeOccurredAndNoOneVerifiedOnTheWinningOption(async (Bet, chip, { hacker }) => {
          await Bet.write.release({ account: hacker.account })
        }, async (Bet, chip, { hacker }) => {
          await Bet.write.penalize({ account: hacker.account })
        }, isPenalizeFirst)

        // Step-by-step release and penalize
        await confirmedAfterDisputeOccurredAndNoOneVerifiedOnTheWinningOption(async (Bet, chip, { hacker }) => {
          const [done, total] = await Bet.read.releasedProgress()
          assert.equal(done, 0n)
          for (let i = 0; i < Number(total); i++) {
            await Bet.write.release([1n], { account: hacker.account })
          }
          assert.deepEqual(await Bet.read.releasedProgress(), [total, total])
        }, async (Bet, chip, { hacker }) => {
          const [done, total] = await Bet.read.penalizedProgress()
          assert.equal(done, 0n)
          for (let i = 0; i < Number(total); i++) {
            await Bet.write.penalize([1n], { account: hacker.account })
          }
          assert.deepEqual(await Bet.read.penalizedProgress(), [total, total])
        }, isPenalizeFirst)
      }
    })

    it('Release when confirmed after dispute occurred, and punish disputer', async () => {
      for (const isPenalizeFirst of [false, true]) {
        await confirmedAfterDisputeOccurredAndPunishDisputer(async (Bet, chip, { hacker }) => {
          await Bet.write.release({ account: hacker.account })
        }, async (Bet, chip, { hacker }) => {
          await Bet.write.penalize({ account: hacker.account })
        }, isPenalizeFirst)

        // Step-by-step release and penalize
        await confirmedAfterDisputeOccurredAndPunishDisputer(async (Bet, chip, { hacker }) => {
          const [done, total] = await Bet.read.releasedProgress()
          assert.equal(done, 0n)
          for (let i = 0; i < Number(total); i++) {
            await Bet.write.release([1n], { account: hacker.account })
          }
          assert.deepEqual(await Bet.read.releasedProgress(), [total, total])
        }, async (Bet, chip, { hacker }) => {
          const [done, total] = await Bet.read.penalizedProgress()
          assert.equal(done, 0n)
          for (let i = 0; i < Number(total); i++) {
            await Bet.write.penalize([1n], { account: hacker.account })
          }
          assert.deepEqual(await Bet.read.penalizedProgress(), [total, total])
        }, isPenalizeFirst)
      }
    })

    it('Release when confirmed after dispute occurred, and punish verifier', async () => {
      for (const isPenalizeFirst of [false, true]) {
        await confirmedAfterDisputeOccurredAndPunishVerifier(async (Bet, chip, { hacker }) => {
          await Bet.write.release({ account: hacker.account })
        }, async (Bet, chip, { hacker }) => {
          await Bet.write.penalize({ account: hacker.account })
        }, isPenalizeFirst)

        // Step-by-step release and penalize
        await confirmedAfterDisputeOccurredAndPunishVerifier(async (Bet, chip, { hacker }) => {
          const [done, total] = await Bet.read.releasedProgress()
          assert.equal(done, 0n)
          for (let i = 0; i < Number(total); i++) {
            await Bet.write.release([1n], { account: hacker.account })
          }
          assert.deepEqual(await Bet.read.releasedProgress(), [total, total])
        }, async (Bet, chip, { hacker }) => {
          const [done, total] = await Bet.read.penalizedProgress()
          assert.equal(done, 0n)
          for (let i = 0; i < Number(total); i++) {
            await Bet.write.penalize([1n], { account: hacker.account })
          }
          assert.deepEqual(await Bet.read.penalizedProgress(), [total, total])
        }, isPenalizeFirst)
      }
    })

    it('Invalid release', async () => {
      const {
        BetChip,
        VotingEscrow,
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
        const Bet = await createBet(
          user,
          BetManager,
          BetDetails,
          WEEK,
          DAY3,
          chip,
        )
        const options = await Bet.read.options()
        await wager(chip, [
          [owner, options[0], 2n],
          [user, options[1], 9n],
          [hacker, options[1], 1n],
        ], Bet)
        await time.increaseTo(await Bet.read.statusDeadline() + 1n)
        assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

        await decide(VotingEscrow.address, [
          [owner, options[0], 6n],
          [user, options[1], 3n],
          [hacker, options[1], 2n],
        ], Bet)
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
        VotingEscrow,
        BetManager,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const AttackContract = await viem.deployContract('AttackContract', [zeroAddress])
      const hash = await AttackContract.write.functionCall(
        [
          BetManager.address,
          encodeFunctionData({
            abi: BetManager.abi,
            functionName: 'createBet',
            args: [
              BetDetails,
              WEEK,
              DAY3,
            ],
          }),
        ],
        { account: hacker.account },
      )
      const Bet = await getBetByHash(hash, BetManager)
      const options = await Bet.read.options()

      await assert.isRejected(
        viem.deployContract(
          'AttackContract',
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
      assert.equal(await Bet.read.status(), BetStatus.VERIFYING)

      await decide(VotingEscrow.address, [
        [owner, options[0], 6n],
        [user, options[1], 3n],
        [hacker, options[1], 2n],
      ], Bet)
      await time.increaseTo(await Bet.read.statusDeadline() + 1n)
      assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

      await assert.isRejected(
        viem.deployContract(
          'AttackContract',
          [Bet.address],
          { value: parseEther('1') },
        ),
        'TransferFailed',
      )

      assert.equal(await Bet.read.status(), BetStatus.ANNOUNCEMENT)

      await time.increaseTo(await Bet.read.statusDeadline() + 1n)
      assert.equal(await Bet.read.status(), BetStatus.CONFIRMED)

      const creatorReward = await getCreatorReward(Bet)

      // The creator is unable to claim the reward, so it was sent to the `BetManager`.
      await checkBalance(
        async () => {
          await Bet.write.release({ account: hacker.account })
        },
        [
          [BetManager.address, zeroAddress, creatorReward],
        ],
      )
      assert.equal(await Bet.read.status(), BetStatus.CLOSED)
    })
  })
})
