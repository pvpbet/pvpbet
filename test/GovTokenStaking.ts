import { loadFixture, time } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  getAddress,
  isAddressEqual,
  parseEther,
  parseUnits,
  zeroAddress,
} from 'viem'
import {
  claimTestTokens,
  deployGovToken,
  deployTestTokens,
} from './common'
import {
  buyChip,
  createBetChip,
  deployBetChipManager,
} from './common/chip'
import {
  UnlockWaitingPeriod,
  deployGovTokenStaking,
  distribute,
  stake,
  unstake,
  withdraw,
} from './common/staking'
import { deployVotingEscrow } from './common/vote'
import { checkBalance } from './asserts'
import type { Address } from 'viem'

const Time = {
  [UnlockWaitingPeriod.NONE]: 0n,
  [UnlockWaitingPeriod.WEEK]: 3600n * 24n * 7n,
  [UnlockWaitingPeriod.WEEK12]: 3600n * 24n * 7n * 12n,
}

describe('GovTokenStaking', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const testTokens = await deployTestTokens()
    await claimTestTokens(owner, testTokens)

    const { USDC } = testTokens
    const BetChipManager = await deployBetChipManager()
    const BetChip = await createBetChip(owner, BetChipManager, USDC.address)
    const VotingEscrow = await deployVotingEscrow()
    const GovToken = await deployGovToken()
    const GovTokenStaking = await deployGovTokenStaking(VotingEscrow.address, GovToken.address, BetChip.address)

    await VotingEscrow.write.setGovTokenStaking([GovTokenStaking.address])
    await GovToken.write.transfer([user.account.address, parseUnits('1000000', 18)])
    await GovToken.write.transfer([hacker.account.address, parseUnits('1000000', 18)])

    await buyChip(
      owner,
      BetChip,
      USDC.address,
      parseUnits('1000000', await USDC.read.decimals()),
    )

    return {
      ...testTokens,
      BetChip,
      VotingEscrow,
      GovToken,
      GovTokenStaking,
      publicClient,
      owner,
      user,
      hacker,
    }
  }

  describe('Ownable', () => {
    it('#owner()', async () => {
      const {
        GovTokenStaking,
        owner,
      } = await loadFixture(deployFixture)
      assert.equal(
        await GovTokenStaking.read.owner(),
        getAddress(owner.account.address),
      )
    })

    it('#transferOwnership()', async () => {
      const {
        GovTokenStaking,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        GovTokenStaking.write.transferOwnership([hacker.account.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await GovTokenStaking.write.transferOwnership([hacker.account.address], { account: owner.account })
      assert.equal(
        await GovTokenStaking.read.owner(),
        getAddress(hacker.account.address),
      )
    })
  })

  describe('Config contracts', () => {
    it('#govToken() #setGovToken()', async () => {
      const {
        BetChip,
        GovTokenStaking,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        GovTokenStaking.write.setGovToken([BetChip.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await GovTokenStaking.write.setGovToken([BetChip.address], { account: owner.account })
      assert.equal(
        await GovTokenStaking.read.govToken(),
        BetChip.address,
      )
    })

    it('#votingEscrow() #setVotingEscrow()', async () => {
      const {
        GovTokenStaking,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        GovTokenStaking.write.setVotingEscrow([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await GovTokenStaking.write.setVotingEscrow([zeroAddress], { account: owner.account })
      assert.equal(
        await GovTokenStaking.read.votingEscrow(),
        zeroAddress,
      )
    })

    it('#rewardTokens() #setRewardTokens()', async () => {
      const {
        BetChip,
        GovTokenStaking,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        GovTokenStaking.write.setRewardTokens([[zeroAddress]], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await GovTokenStaking.write.setRewardTokens([[zeroAddress]], { account: owner.account })
      assert.deepEqual(
        await GovTokenStaking.read.rewardTokens(),
        [zeroAddress],
      )

      await GovTokenStaking.write.setRewardTokens([[BetChip.address, zeroAddress]], { account: owner.account })
      assert.deepEqual(
        await GovTokenStaking.read.rewardTokens(),
        [BetChip.address, zeroAddress],
      )
    })
  })

  describe('Staking', async () => {
    it('#stake() #stakedAmount()', async () => {
      const {
        GovToken,
        GovTokenStaking,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      const amountPerWeight = 10n ** 18n

      await assert.isRejected(
        stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12 + 1, stakeAmount),
      )
      await assert.isRejected(
        stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.NONE, stakeAmount),
        'InvalidUnlockWaitingPeriod',
      )
      await assert.isRejected(
        stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, 0n),
        'InvalidAmount',
      )

      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)

      const accounts = [
        { wallet: user, stakedAmountForWeek: stakeAmount, stakedAmountForWeek12: stakeAmount * 2n },
        { wallet: hacker, stakedAmountForWeek: stakeAmount * 2n, stakedAmountForWeek12: 0n },
      ]

      assert.equal(
        await GovTokenStaking.read.stakedAmount(),
        accounts.reduce((acc, cur) => acc + cur.stakedAmountForWeek + cur.stakedAmountForWeek12, 0n),
      )
      assert.equal(
        await GovTokenStaking.read.stakedAmount([UnlockWaitingPeriod.WEEK]),
        accounts.reduce((acc, cur) => acc + cur.stakedAmountForWeek, 0n),
      )
      assert.equal(
        await GovTokenStaking.read.stakedAmount([UnlockWaitingPeriod.WEEK12]),
        accounts.reduce((acc, cur) => acc + cur.stakedAmountForWeek12, 0n),
      )
      assert.equal(
        await GovTokenStaking.read.stakedWeight(),
        accounts.reduce((acc, cur) => acc + cur.stakedAmountForWeek + cur.stakedAmountForWeek12 * 2n, 0n) / amountPerWeight,
      )

      for (const { wallet, stakedAmountForWeek, stakedAmountForWeek12 } of accounts) {
        assert.equal(
          await GovTokenStaking.read.stakedAmount([wallet.account.address]),
          stakedAmountForWeek + stakedAmountForWeek12,
        )
        assert.equal(
          await GovTokenStaking.read.stakedAmount([wallet.account.address, UnlockWaitingPeriod.WEEK]),
          stakedAmountForWeek,
        )
        assert.equal(
          await GovTokenStaking.read.stakedAmount([wallet.account.address, UnlockWaitingPeriod.WEEK12]),
          stakedAmountForWeek12,
        )
        assert.equal(
          await GovTokenStaking.read.stakedAmount([wallet.account.address, 0]),
          0n,
        )

        assert.equal(
          await GovTokenStaking.read.stakedWeight([wallet.account.address]),
          (stakedAmountForWeek + stakedAmountForWeek12 * 2n) / amountPerWeight,
        )
      }
    })

    it('#unstake() #unstakedRecords()', async () => {
      const {
        GovToken,
        GovTokenStaking,
        VotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      const accounts = [
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12 },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK },
      ]

      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      for (const { wallet, unlockWaitingPeriod } of accounts) {
        await stake(wallet, GovToken, GovTokenStaking, unlockWaitingPeriod, stakeAmount)

        await assert.isRejected(
          unstake(wallet, GovTokenStaking, 0, stakeAmount),
          'NoStakedRecordFound',
        )
        await assert.isRejected(
          unstake(wallet, GovTokenStaking, unlockWaitingPeriod, stakeAmount + 1n),
          'StakedAmountInsufficientBalance',
        )
      }

      const unstakeAmountArr: bigint[] = []
      const unstakeStartTimeMap: Record<Address, number[]> = {
        [user.account.address]: [],
        [hacker.account.address]: [],
      }
      const length = 4
      const count = new Array(length).fill(0).reduce((acc, cur, index) => acc + index + 1, 0)
      for (let i = 0; i < length; i++) {
        unstakeAmountArr.push(stakeAmount * BigInt(i + 1) / BigInt(count))
        const stakedAmount = stakeAmount - unstakeAmountArr.reduce((acc, cur) => acc + cur, 0n)
        for (const { wallet, unlockWaitingPeriod } of accounts) {
          await unstake(wallet, GovTokenStaking, unlockWaitingPeriod, unstakeAmountArr[i])
          unstakeStartTimeMap[wallet.account.address].push(await time.latest())
        }

        for (const { wallet, unlockWaitingPeriod } of accounts) {
          assert.equal(
            await VotingEscrow.read.balanceOf([wallet.account.address]),
            stakeAmount + stakedAmount,
          )
          assert.equal(
            await GovTokenStaking.read.stakedAmount([wallet.account.address, unlockWaitingPeriod]),
            stakedAmount,
          )
          assert.deepEqual(
            await GovTokenStaking.read.unstakedRecords([wallet.account.address, unlockWaitingPeriod]),
            unstakeStartTimeMap[wallet.account.address].map((unstakeStartTime, index) => ({
              unlockWaitingPeriod: unlockWaitingPeriod,
              amount: unstakeAmountArr[index],
              unlockTime: BigInt(unstakeStartTime) + Time[unlockWaitingPeriod],
            })),
          )
        }
      }
    })

    it('#restake()', async () => {
      const {
        GovToken,
        GovTokenStaking,
        VotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      const accounts = [
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12 },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK },
      ]

      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      for (const { wallet, unlockWaitingPeriod } of accounts) {
        await stake(wallet, GovToken, GovTokenStaking, unlockWaitingPeriod, stakeAmount)
      }

      assert.equal(
        await GovTokenStaking.read.stakedAmount(),
        stakeAmount * 4n,
      )

      const unstakeAmountArr: bigint[] = []
      const unstakeStartTimeMap: Record<Address, number[]> = {
        [user.account.address]: [],
        [hacker.account.address]: [],
      }
      const length = 4
      const count = new Array(length).fill(0).reduce((acc, cur, index) => acc + index + 1, 0)
      for (let i = 0; i < length; i++) {
        unstakeAmountArr.push(stakeAmount * BigInt(i + 1) / BigInt(count))
        for (const { wallet, unlockWaitingPeriod } of accounts) {
          await unstake(wallet, GovTokenStaking, unlockWaitingPeriod, unstakeAmountArr[i])
          unstakeStartTimeMap[wallet.account.address].push(await time.latest())
        }
      }

      assert.equal(
        await GovTokenStaking.read.stakedAmount(),
        stakeAmount * 2n,
      )

      for (let i = 0; i < length; i++) {
        const stakedAmount = unstakeAmountArr.slice(0, i + 1).reduce((acc, cur) => acc + cur, 0n)
        for (const { wallet } of accounts) {
          await GovTokenStaking.write.restake([0n], { account: wallet.account })
        }

        for (const { wallet, unlockWaitingPeriod } of accounts) {
          assert.equal(
            await VotingEscrow.read.balanceOf([wallet.account.address]),
            stakeAmount + stakedAmount,
          )
          assert.equal(
            await GovTokenStaking.read.stakedAmount([wallet.account.address]),
            stakeAmount + stakedAmount,
          )
          assert.equal(
            await GovTokenStaking.read.stakedAmount([wallet.account.address, unlockWaitingPeriod]),
            stakedAmount,
          )
          assert.deepEqual(
            await GovTokenStaking.read.unstakedRecords([wallet.account.address, unlockWaitingPeriod]),
            unstakeStartTimeMap[wallet.account.address].slice(i + 1).map((unstakeStartTime, index) => ({
              unlockWaitingPeriod: unlockWaitingPeriod,
              amount: unstakeAmountArr[i + 1 + index],
              unlockTime: BigInt(unstakeStartTime) + Time[unlockWaitingPeriod],
            })),
          )
        }
      }

      assert.equal(
        await GovTokenStaking.read.stakedAmount(),
        stakeAmount * 4n,
      )
    })

    it('#extendUnlockWaitingPeriod()', async () => {
      const {
        GovToken,
        GovTokenStaking,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)

      const length = 4
      for (let i = 0; i < length; i++) {
        await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
        assert.equal(
          await GovTokenStaking.read.stakedAmount([user.account.address, UnlockWaitingPeriod.WEEK]),
          stakeAmount,
        )
        assert.equal(
          await GovTokenStaking.read.stakedAmount([user.account.address, UnlockWaitingPeriod.WEEK12]),
          stakeAmount * BigInt(i),
        )

        await assert.isRejected(
          GovTokenStaking.write.extendUnlockWaitingPeriod(
            [UnlockWaitingPeriod.WEEK, UnlockWaitingPeriod.WEEK12 + 1],
            { account: user.account },
          ),
        )
        await assert.isRejected(
          GovTokenStaking.write.extendUnlockWaitingPeriod(
            [UnlockWaitingPeriod.WEEK12, UnlockWaitingPeriod.WEEK],
            { account: user.account },
          ),
          'InvalidUnlockWaitingPeriod',
        )
        await assert.isRejected(
          GovTokenStaking.write.extendUnlockWaitingPeriod(
            [UnlockWaitingPeriod.NONE, UnlockWaitingPeriod.WEEK12],
            { account: user.account },
          ),
          'NoStakedRecordFound',
        )
        await GovTokenStaking.write.extendUnlockWaitingPeriod(
          [UnlockWaitingPeriod.WEEK, UnlockWaitingPeriod.WEEK12],
          { account: user.account },
        )
        assert.equal(
          await GovTokenStaking.read.stakedAmount([user.account.address, UnlockWaitingPeriod.WEEK]),
          0n,
        )
        assert.equal(
          await GovTokenStaking.read.stakedAmount([user.account.address, UnlockWaitingPeriod.WEEK12]),
          stakeAmount * BigInt(i + 1),
        )
      }

      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await GovTokenStaking.read.stakedAmount([hacker.account.address, UnlockWaitingPeriod.WEEK]),
        stakeAmount,
      )
      assert.equal(
        await GovTokenStaking.read.stakedAmount([hacker.account.address, UnlockWaitingPeriod.WEEK12]),
        0n,
      )

      const perAmount = stakeAmount / BigInt(length)
      for (let i = 0; i < length; i++) {
        await assert.isRejected(
          GovTokenStaking.write.extendUnlockWaitingPeriod(
            [UnlockWaitingPeriod.WEEK, UnlockWaitingPeriod.WEEK12 + 1, perAmount],
            { account: hacker.account },
          ),
        )
        await assert.isRejected(
          GovTokenStaking.write.extendUnlockWaitingPeriod(
            [UnlockWaitingPeriod.WEEK12, UnlockWaitingPeriod.WEEK, perAmount],
            { account: hacker.account },
          ),
          'InvalidUnlockWaitingPeriod',
        )
        await assert.isRejected(
          GovTokenStaking.write.extendUnlockWaitingPeriod(
            [UnlockWaitingPeriod.NONE, UnlockWaitingPeriod.WEEK12, perAmount],
            { account: hacker.account },
          ),
          'NoStakedRecordFound',
        )
        await GovTokenStaking.write.extendUnlockWaitingPeriod(
          [UnlockWaitingPeriod.WEEK, UnlockWaitingPeriod.WEEK12, perAmount],
          { account: hacker.account },
        )
        const stakedAmountForWeek12 = perAmount * BigInt(i + 1)
        assert.equal(
          await GovTokenStaking.read.stakedAmount([hacker.account.address, UnlockWaitingPeriod.WEEK]),
          stakeAmount - stakedAmountForWeek12,
        )
        assert.equal(
          await GovTokenStaking.read.stakedAmount([hacker.account.address, UnlockWaitingPeriod.WEEK12]),
          stakedAmountForWeek12,
        )
      }
    })

    it('#withdraw()', async () => {
      const {
        GovToken,
        GovTokenStaking,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)

      const unstakeAmount = stakeAmount / 4n
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK, unstakeAmount)
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK12, unstakeAmount)
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK, unstakeAmount)
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK12, unstakeAmount)

      await checkBalance(
        async () => {
          await withdraw(user, GovTokenStaking)
        },
        [
          [user.account.address, GovToken.address, 0n],
        ],
      )

      await time.increase(Time[UnlockWaitingPeriod.WEEK])
      await checkBalance(
        async () => {
          await withdraw(user, GovTokenStaking)
        },
        [
          [user.account.address, GovToken.address, unstakeAmount * 2n],
        ],
      )

      await time.increase(Time[UnlockWaitingPeriod.WEEK12])
      await checkBalance(
        async () => {
          await withdraw(user, GovTokenStaking)
        },
        [
          [user.account.address, GovToken.address, unstakeAmount * 2n],
        ],
      )

      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK)
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK12)
      await time.increase(Time[UnlockWaitingPeriod.WEEK12])
      await checkBalance(
        async () => {
          await withdraw(user, GovTokenStaking)
        },
        [
          [user.account.address, GovToken.address, unstakeAmount * 4n],
        ],
      )
    })

    it('Clear dust when unstake', async () => {
      const {
        GovToken,
        GovTokenStaking,
        VotingEscrow,
        user,
      } = await loadFixture(deployFixture)
      const stakeMinValue = await GovTokenStaking.read.stakeMinValue()

      await assert.isRejected(
        stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue - 1n),
        'InvalidAmount',
      )

      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue)
      assert.equal(
        await GovTokenStaking.read.stakedAmount(),
        stakeMinValue,
      )
      assert.equal(
        await GovTokenStaking.read.stakedAmount([user.account.address]),
        stakeMinValue,
      )

      await checkBalance(
        async () => {
          await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK, 1n)
        },
        [
          [user.account.address, VotingEscrow.address, -stakeMinValue],
        ],
      )

      assert.equal(
        await GovTokenStaking.read.stakedAmount(),
        0n,
      )
      assert.equal(
        await GovTokenStaking.read.stakedAmount([user.account.address]),
        0n,
      )
    })

    it('Ignore dust in weight calculation', async () => {
      const {
        GovToken,
        GovTokenStaking,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeMinValue = await GovTokenStaking.read.stakeMinValue()
      const stakeMinValueHalf = stakeMinValue * 5n / 10n

      await assert.isRejected(
        stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue - 1n),
        'InvalidAmount',
      )
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue) // 1
      assert.equal(await GovTokenStaking.read.stakedWeight([hacker.account.address]), 1)
      assert.equal(await GovTokenStaking.read.stakedAmount([hacker.account.address]), stakeMinValue)
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue + stakeMinValueHalf) // 2.5
      assert.equal(await GovTokenStaking.read.stakedWeight([hacker.account.address]), 2)
      assert.equal(await GovTokenStaking.read.stakedAmount([hacker.account.address]), stakeMinValue * 2n + stakeMinValueHalf)
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue + stakeMinValueHalf) // 4
      assert.equal(await GovTokenStaking.read.stakedWeight([hacker.account.address]), 4)
      assert.equal(await GovTokenStaking.read.stakedAmount([hacker.account.address]), stakeMinValue * 4n)

      await unstake(hacker, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValueHalf) // 3.5
      assert.equal(await GovTokenStaking.read.stakedWeight([hacker.account.address]), 3)
      assert.equal(await GovTokenStaking.read.stakedAmount([hacker.account.address]), stakeMinValue * 3n + stakeMinValueHalf)
      await unstake(hacker, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValueHalf) // 3
      assert.equal(await GovTokenStaking.read.stakedWeight([hacker.account.address]), 3)
      assert.equal(await GovTokenStaking.read.stakedAmount([hacker.account.address]), stakeMinValue * 3n)
      await unstake(hacker, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue + stakeMinValueHalf) // 1.5
      assert.equal(await GovTokenStaking.read.stakedWeight([hacker.account.address]), 1)
      assert.equal(await GovTokenStaking.read.stakedAmount([hacker.account.address]), stakeMinValue * 1n + stakeMinValueHalf)
      await unstake(hacker, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue) // 0.5 => 0
      assert.equal(await GovTokenStaking.read.stakedWeight([hacker.account.address]), 0)
      assert.equal(await GovTokenStaking.read.stakedAmount([hacker.account.address]), 0)
    })
  })

  describe('Distribute rewards', () => {
    it('#distribute() #claimedRewards() #unclaimedRewards()', async () => {
      const {
        BetChip,
        GovToken,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const accounts = [
        { wallet: owner, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakeRatio: 2n },
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakeRatio: 5n },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK, stakeRatio: 3n },
      ]
      const tokens: [Address, bigint][] = [
        [zeroAddress, parseEther('10')],
        [BetChip.address, parseUnits('10000', 6)],
      ]

      for (const { wallet } of accounts) {
        for (const [token] of tokens) {
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.claimedRewards([wallet.account.address])
              : await GovTokenStaking.read.claimedRewards([wallet.account.address, token]),
            0n,
          )
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.unclaimedRewards([wallet.account.address])
              : await GovTokenStaking.read.unclaimedRewards([wallet.account.address, token]),
            0n,
          )
        }
      }

      for (const [token, amount] of tokens) {
        await distribute(owner, GovTokenStaking, token, amount)
      }

      for (const { wallet } of accounts) {
        for (const [token] of tokens) {
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.claimedRewards([wallet.account.address])
              : await GovTokenStaking.read.claimedRewards([wallet.account.address, token]),
            0n,
          )
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.unclaimedRewards([wallet.account.address])
              : await GovTokenStaking.read.unclaimedRewards([wallet.account.address, token]),
            0n,
          )
        }
      }

      // Staking
      const stakedTotalAmount = parseUnits('100000', 18)
      const stakeCount = accounts.reduce((acc, cur) => acc + cur.stakeRatio, 0n)
      for (const { wallet, unlockWaitingPeriod, stakeRatio } of accounts) {
        await stake(wallet, GovToken, GovTokenStaking, unlockWaitingPeriod, stakedTotalAmount * stakeRatio / stakeCount)
      }

      for (const [token, amount] of tokens) {
        await distribute(owner, GovTokenStaking, token, amount)
      }

      const stakedTotalWeight = await GovTokenStaking.read.stakedWeight()
      for (const { wallet } of accounts) {
        const stakedWeight = await GovTokenStaking.read.stakedWeight([wallet.account.address])
        for (const [token, amount] of tokens) {
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.claimedRewards([wallet.account.address])
              : await GovTokenStaking.read.claimedRewards([wallet.account.address, token]),
            0n,
          )
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.unclaimedRewards([wallet.account.address])
              : await GovTokenStaking.read.unclaimedRewards([wallet.account.address, token]),
            amount / stakedTotalWeight * stakedWeight,
          )
        }
      }
    })

    it('#accRewardPerWeight() #rewardDebt()', async () => {
      const {
        BetChip,
        GovToken,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const accounts = [
        { wallet: owner, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakeRatio: 2n },
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakeRatio: 5n },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK, stakeRatio: 3n },
      ]
      const tokens: [Address, bigint][] = [
        [zeroAddress, parseEther('10')],
        [BetChip.address, parseUnits('10000', 6)],
      ]

      for (const [token] of tokens) {
        assert.equal(
          isAddressEqual(zeroAddress, token)
            ? await GovTokenStaking.read.accRewardPerWeight()
            : await GovTokenStaking.read.accRewardPerWeight([token]),
          0n,
        )
      }

      // Staking
      const stakedTotalAmount = parseUnits('100000', 18)
      const stakeCount = accounts.reduce((acc, cur) => acc + cur.stakeRatio, 0n)
      for (const { wallet, unlockWaitingPeriod, stakeRatio } of accounts) {
        await stake(wallet, GovToken, GovTokenStaking, unlockWaitingPeriod, stakedTotalAmount * stakeRatio / stakeCount)
      }

      for (const [token, amount] of tokens) {
        await distribute(owner, GovTokenStaking, token, amount)
      }

      const stakedTotalWeight = await GovTokenStaking.read.stakedWeight()
      for (const [token, rewards] of tokens) {
        assert.equal(
          isAddressEqual(zeroAddress, token)
            ? await GovTokenStaking.read.accRewardPerWeight()
            : await GovTokenStaking.read.accRewardPerWeight([token]),
          rewards / stakedTotalWeight,
        )

        for (const { wallet } of accounts) {
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.rewardDebt([wallet.account.address])
              : await GovTokenStaking.read.rewardDebt([wallet.account.address, token]),
            0n,
          )
        }
      }

      for (const { wallet, unlockWaitingPeriod, stakeRatio } of accounts) {
        const stakedAmount = stakedTotalAmount * stakeRatio / stakeCount
        const weight = stakedAmount * (unlockWaitingPeriod === UnlockWaitingPeriod.WEEK12 ? 2n : 1n) / (10n ** 18n)
        await stake(wallet, GovToken, GovTokenStaking, unlockWaitingPeriod, stakedAmount)

        for (const [token] of tokens) {
          const accRewardPerWeight = isAddressEqual(zeroAddress, token)
            ? await GovTokenStaking.read.accRewardPerWeight()
            : await GovTokenStaking.read.accRewardPerWeight([token])
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.rewardDebt([wallet.account.address])
              : await GovTokenStaking.read.rewardDebt([wallet.account.address, token]),
            accRewardPerWeight * weight,
          )
        }
      }
    })

    it('#claim() #rewardDebt()', async () => {
      const {
        BetChip,
        GovToken,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const accounts = [
        { wallet: owner, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakeRatio: 2n },
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakeRatio: 5n },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK, stakeRatio: 3n },
      ]
      const tokens: [Address, bigint][] = [
        [zeroAddress, parseEther('10')],
        [BetChip.address, parseUnits('10000', 6)],
      ]

      // Staking
      const stakedTotalAmount = parseUnits('100000', 18)
      const stakeCount = accounts.reduce((acc, cur) => acc + cur.stakeRatio, 0n)
      for (const { wallet, unlockWaitingPeriod, stakeRatio } of accounts) {
        await stake(wallet, GovToken, GovTokenStaking, unlockWaitingPeriod, stakedTotalAmount * stakeRatio / stakeCount)
      }

      for (const { wallet } of accounts) {
        for (const [token] of tokens) {
          await assert.isRejected(
            isAddressEqual(zeroAddress, token)
              ? GovTokenStaking.write.claim({ account: wallet.account })
              : GovTokenStaking.write.claim([token], { account: wallet.account }),
            'NoClaimableRewards',
          )
        }
      }

      for (const [token, amount] of tokens) {
        await distribute(owner, GovTokenStaking, token, amount)
      }

      const stakedTotalWeight = await GovTokenStaking.read.stakedWeight()
      for (const { wallet } of accounts) {
        const stakedWeight = await GovTokenStaking.read.stakedWeight([wallet.account.address])
        for (const [token, amount] of tokens) {
          await checkBalance(
            async () => {
              isAddressEqual(zeroAddress, token)
                ? await GovTokenStaking.write.claim({ account: wallet.account })
                : await GovTokenStaking.write.claim([token], { account: wallet.account })
            },
            [
              [wallet.account.address, token, amount / stakedTotalWeight * stakedWeight],
            ],
          )
        }
      }

      for (const { wallet } of accounts) {
        const stakedWeight = await GovTokenStaking.read.stakedWeight([wallet.account.address])
        for (const [token, amount] of tokens) {
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.claimedRewards([wallet.account.address])
              : await GovTokenStaking.read.claimedRewards([wallet.account.address, token]),
            amount / stakedTotalWeight * stakedWeight,
          )
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await GovTokenStaking.read.unclaimedRewards([wallet.account.address])
              : await GovTokenStaking.read.unclaimedRewards([wallet.account.address, token]),
            0n,
          )
        }
      }
    })

    it('As staking increases, the reward distribution is correct', async () => {
      const {
        BetChip,
        GovToken,
        GovTokenStaking,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const accounts = [
        { wallet: owner, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12 },
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12 },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK },
      ]

      const tokens: [Address, bigint][] = [
        [zeroAddress, parseEther('10')],
        [BetChip.address, parseUnits('10000', 6)],
      ]

      const stakeAmount = parseUnits('10000', 18)
      const claimedRewards = {} as Record<Address, Record<Address, bigint>>
      const unclaimedRewards = {} as Record<Address, Record<Address, bigint>>

      for (const { wallet } of accounts) {
        claimedRewards[wallet.account.address] = {} as Record<Address, bigint>
        unclaimedRewards[wallet.account.address] = {} as Record<Address, bigint>
        for (const [token] of tokens) {
          claimedRewards[wallet.account.address][token] = 0n
          unclaimedRewards[wallet.account.address][token] = 0n
        }
      }

      let stakedTotalWeight = 0n
      const amountPerWeight = 10n ** 18n
      for (const { wallet, unlockWaitingPeriod } of accounts) {
        await stake(wallet, GovToken, GovTokenStaking, unlockWaitingPeriod, stakeAmount)
        const stakedWeight = stakeAmount / amountPerWeight * (unlockWaitingPeriod === UnlockWaitingPeriod.WEEK12 ? 2n : 1n)
        stakedTotalWeight += stakedWeight
        assert.equal(
          await GovTokenStaking.read.stakedWeight([wallet.account.address]),
          stakedWeight,
        )
        assert.equal(
          await GovTokenStaking.read.stakedWeight(),
          stakedTotalWeight,
        )

        for (const [token, amount] of tokens) {
          await distribute(owner, GovTokenStaking, token, amount)

          for (const item of accounts) {
            const itemStakedWeight = await GovTokenStaking.read.stakedWeight([item.wallet.account.address])
            const itemReward = amount / stakedTotalWeight * itemStakedWeight
            unclaimedRewards[item.wallet.account.address][token] += itemReward
            assert.equal(
              isAddressEqual(zeroAddress, token)
                ? await GovTokenStaking.read.claimedRewards([item.wallet.account.address])
                : await GovTokenStaking.read.claimedRewards([item.wallet.account.address, token]),
              claimedRewards[item.wallet.account.address][token],
            )
            assert.equal(
              isAddressEqual(zeroAddress, token)
                ? await GovTokenStaking.read.unclaimedRewards([item.wallet.account.address])
                : await GovTokenStaking.read.unclaimedRewards([item.wallet.account.address, token]),
              unclaimedRewards[item.wallet.account.address][token],
            )
          }

          await GovTokenStaking.write.claim([token], { account: wallet.account })
          const reward = amount / stakedTotalWeight * stakedWeight
          unclaimedRewards[wallet.account.address][token] -= reward
          claimedRewards[wallet.account.address][token] += reward

          for (const item of accounts) {
            assert.equal(
              isAddressEqual(zeroAddress, token)
                ? await GovTokenStaking.read.claimedRewards([item.wallet.account.address])
                : await GovTokenStaking.read.claimedRewards([item.wallet.account.address, token]),
              claimedRewards[item.wallet.account.address][token],
            )
            assert.equal(
              isAddressEqual(zeroAddress, token)
                ? await GovTokenStaking.read.unclaimedRewards([item.wallet.account.address])
                : await GovTokenStaking.read.unclaimedRewards([item.wallet.account.address, token]),
              unclaimedRewards[item.wallet.account.address][token],
            )
          }
        }
      }
    })
  })
})
