import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  getAddress,
  parseUnits,
  zeroAddress,
} from 'viem'
import {
  deployGovToken,
  deployTestTokens,
} from './common'
import {
  BetDetails,
  createBet,
  deployBetManager,
} from './common/bet'
import {
  createBetChip,
  deployBetChipManager,
} from './common/chip'
import { deployVotingEscrow } from './common/vote'
import { testReceivable } from './asserts/Receivable'
import { testWithdrawable } from './asserts/Withdrawable'
import type { ContractTypes } from '../types'

const DAY = 24n * 3600n
const DAY3 = 3n * DAY
const WEEK = 7n * DAY

describe('BetManager', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const testTokens = await deployTestTokens()
    const { USDC } = testTokens
    const BetChipManager = await deployBetChipManager()
    const BetChip = await createBetChip(owner, BetChipManager, USDC.address)
    const VotingEscrow = await deployVotingEscrow()
    const GovToken = await deployGovToken()
    const BetManager = await deployBetManager(BetChipManager.address, VotingEscrow.address, GovToken.address)
    const BetConfigurator = await viem.getContractAt('BetConfigurator', await BetManager.read.betConfigurator())

    await GovToken.write.transfer([user.account.address, parseUnits('1000000', 18)])

    return {
      ...testTokens,
      BetChip,
      VotingEscrow,
      BetManager,
      BetConfigurator,
      GovToken,
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

  describe('Configure the contracts', () => {
    it('#betChipManager() #setBetChipManager()', async () => {
      const {
        BetManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetManager.write.setBetChipManager([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetManager.write.setBetChipManager([zeroAddress], { account: owner.account })
      assert.equal(
        await BetManager.read.betChipManager(),
        zeroAddress,
      )
    })

    it('#betConfigurator() #setBetConfigurator()', async () => {
      const {
        BetManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetManager.write.setBetConfigurator([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetManager.write.setBetConfigurator([zeroAddress], { account: owner.account })
      assert.equal(
        await BetManager.read.betConfigurator(),
        zeroAddress,
      )
    })

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

    it('#votingEscrow() #setVotingEscrow()', async () => {
      const {
        BetManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetManager.write.setVotingEscrow([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetManager.write.setVotingEscrow([zeroAddress], { account: owner.account })
      assert.equal(
        await BetManager.read.votingEscrow(),
        zeroAddress,
      )
    })
  })

  describe('Bets management', () => {
    it('Bet configuration', async () => {
      const {
        BetChip,
        BetManager,
        BetConfigurator,
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
        const betConfig = await BetConfigurator.read.betConfig([chip])
        assert.deepEqual(await Bet.read.config(), betConfig)
        assert.equal(await Bet.read.minWageredTotalAmount(), betConfig.minWageredTotalAmount)
      }
    })

    it('Restrictions on creation', async () => {
      const {
        USDC,
        BetChip,
        BetManager,
        BetConfigurator,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const chips = [
        zeroAddress,
        BetChip.address,
      ]

      const MIN_OPTIONS_COUNT = await BetConfigurator.read.minOptionsCount()
      const MAX_OPTIONS_COUNT = await BetConfigurator.read.maxOptionsCount()
      const MIN_WAGERING_PERIOD_DURATION = await BetConfigurator.read.minWageringPeriodDuration()
      const MAX_WAGERING_PERIOD_DURATION = await BetConfigurator.read.maxWageringPeriodDuration()
      const MIN_VERIFYING_PERIOD_DURATION = await BetConfigurator.read.minVerifyingPeriodDuration()
      const MAX_VERIFYING_PERIOD_DURATION = await BetConfigurator.read.maxVerifyingPeriodDuration()

      const originAllowlist = [
        'https://example.com',
      ]
      const forumURL = 'https://example.com/foo'

      for (const chip of chips) {
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
            MIN_VERIFYING_PERIOD_DURATION,
            chip,
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
            MIN_VERIFYING_PERIOD_DURATION,
            chip,
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
            chip,
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
            chip,
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
            chip,
          ),
          'InvalidUrl',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            BetDetails,
            MIN_WAGERING_PERIOD_DURATION - 1n,
            MIN_VERIFYING_PERIOD_DURATION,
            chip,
          ),
          'InvalidWageringPeriodDuration',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            BetDetails,
            MAX_WAGERING_PERIOD_DURATION + 1n,
            MAX_VERIFYING_PERIOD_DURATION,
            chip,
          ),
          'InvalidWageringPeriodDuration',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            BetDetails,
            MIN_WAGERING_PERIOD_DURATION,
            MIN_VERIFYING_PERIOD_DURATION - 1n,
            chip,
          ),
          'InvalidVerifyingPeriodDuration',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            BetDetails,
            MAX_WAGERING_PERIOD_DURATION,
            MAX_VERIFYING_PERIOD_DURATION + 1n,
            chip,
          ),
          'InvalidVerifyingPeriodDuration',
        )

        await assert.isRejected(
          createBet(
            user,
            BetManager,
            BetDetails,
            MAX_WAGERING_PERIOD_DURATION,
            MAX_VERIFYING_PERIOD_DURATION,
            USDC.address,
          ),
          'InvalidChip',
        )
      }

      await assert.isRejected(
        BetConfigurator.write.setOriginAllowlist([originAllowlist], { account: user.account }),
        'OwnableUnauthorizedAccount',
      )
      await BetConfigurator.write.setOriginAllowlist([originAllowlist], { account: owner.account })

      for (const chip of chips) {
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
          chip,
        )
        assert.equal((await Bet.read.details()).forumURL, forumURL)
      }
    })

    it('Create a bet', async () => {
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
      )

      assert.equal(await BetManager.read.isBet([BetManager.address]), false)
      assert.equal(await BetManager.read.isBet([Bet.address]), true)
    })

    it('Creating a bet requires a fee', async () => {
      const {
        GovToken,
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
        ),
        'Underpayment',
      )

      await GovToken.write.approve([BetManager.address, fee], { account: user.account })
      const Bet = await createBet(
        user,
        BetManager,
        BetDetails,
        WEEK,
        DAY3,
      )

      assert.equal(await BetManager.read.isBet([BetManager.address]), false)
      assert.equal(await BetManager.read.isBet([Bet.address]), true)
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
