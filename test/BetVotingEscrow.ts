import { loadFixture, time } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  encodeFunctionData,
  getAddress,
  isAddressEqual,
  parseEther,
  parseUnits,
  zeroAddress,
} from 'viem'
import { erc20Transfer } from '../utils'
import {
  claimTestTokens,
  deployBetGovToken,
  deployTestTokens,
} from './common'
import {
  UnlockWaitingPeriod,
  deployBetVotingEscrow,
  distribute,
  stake,
  unstake,
  withdraw,
} from './common/vote'
import { checkBalance } from './asserts'
import type { Address } from 'viem'

const Time = {
  [UnlockWaitingPeriod.NONE]: 0n,
  [UnlockWaitingPeriod.WEEK]: 3600n * 24n * 7n,
  [UnlockWaitingPeriod.WEEK12]: 3600n * 24n * 7n * 12n,
}

describe('BetVotingEscrow', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const testTokens = await deployTestTokens()
    await claimTestTokens(owner, testTokens)

    const BetGovToken = await deployBetGovToken()
    const BetVotingEscrow = await deployBetVotingEscrow(BetGovToken.address)

    await BetGovToken.write.transfer([user.account.address, parseUnits('1000000', 18)])
    await BetGovToken.write.transfer([hacker.account.address, parseUnits('1000000', 18)])

    return {
      ...testTokens,
      BetGovToken,
      BetVotingEscrow,
      publicClient,
      owner,
      user,
      hacker,
    }
  }

  describe('Ownable', () => {
    it('#owner()', async () => {
      const {
        BetVotingEscrow,
        owner,
      } = await loadFixture(deployFixture)
      assert.equal(
        await BetVotingEscrow.read.owner(),
        getAddress(owner.account.address),
      )
    })

    it('#transferOwnership()', async () => {
      const {
        BetVotingEscrow,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetVotingEscrow.write.transferOwnership([hacker.account.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetVotingEscrow.write.transferOwnership([hacker.account.address], { account: owner.account })
      assert.equal(
        await BetVotingEscrow.read.owner(),
        getAddress(hacker.account.address),
      )
    })
  })

  describe('Config contracts', () => {
    it('#govToken() #setGovToken()', async () => {
      const {
        BetVotingEscrow,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetVotingEscrow.write.setGovToken([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetVotingEscrow.write.setGovToken([zeroAddress], { account: owner.account })
      assert.equal(
        await BetVotingEscrow.read.govToken(),
        zeroAddress,
      )
    })

    it('#betManager() #setBetManager()', async () => {
      const {
        BetVotingEscrow,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetVotingEscrow.write.setBetManager([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetVotingEscrow.write.setBetManager([zeroAddress], { account: owner.account })
      assert.equal(
        await BetVotingEscrow.read.betManager(),
        zeroAddress,
      )
    })
  })

  describe('Staking', async () => {
    it('#balanceOf()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
      } = await loadFixture(deployFixture)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        0n,
      )

      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )

      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount * 2n,
      )

      await unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )

      await unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK12)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        0n,
      )
    })

    it('#isAbleToDecide() #isAbleToArbitrate()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
      } = await loadFixture(deployFixture)
      assert.equal(
        await BetVotingEscrow.read.isAbleToDecide([user.account.address]),
        false,
      )
      assert.equal(
        await BetVotingEscrow.read.isAbleToArbitrate([user.account.address]),
        false,
      )

      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.isAbleToDecide([user.account.address]),
        true,
      )
      assert.equal(
        await BetVotingEscrow.read.isAbleToArbitrate([user.account.address]),
        false,
      )

      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.isAbleToDecide([user.account.address]),
        true,
      )
      assert.equal(
        await BetVotingEscrow.read.isAbleToArbitrate([user.account.address]),
        true,
      )
    })

    it('#stake() #stakedAmount() #stakedWeight() #stakedRecord() #stakedRecordCount()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)

      await assert.isRejected(
        stake(user, BetGovToken, BetVotingEscrow, 0, stakeAmount),
        'InvalidUnlockWaitingPeriod',
      )
      await assert.isRejected(
        stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, 0n),
        'InvalidAmount',
      )

      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, stakeAmount)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, stakeAmount)
      await stake(hacker, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(hacker, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)

      const accounts = [
        { wallet: user, stakedAmountForWeek: stakeAmount, stakedAmountForWeek12: stakeAmount * 2n },
        { wallet: hacker, stakedAmountForWeek: stakeAmount * 2n, stakedAmountForWeek12: 0n },
      ]

      assert.equal(
        await BetVotingEscrow.read.stakedAmount(),
        accounts.reduce((acc, cur) => acc + cur.stakedAmountForWeek + cur.stakedAmountForWeek12, 0n),
      )
      assert.equal(
        await BetVotingEscrow.read.stakedWeight(),
        accounts.reduce((acc, cur) => acc + cur.stakedAmountForWeek + cur.stakedAmountForWeek12 * 2n, 0n),
      )
      assert.equal(
        await BetVotingEscrow.read.stakedRecordCount(),
        3n,
      )

      for (const { wallet, stakedAmountForWeek, stakedAmountForWeek12 } of accounts) {
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([wallet.account.address]),
          stakedAmountForWeek + stakedAmountForWeek12,
        )
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([wallet.account.address, UnlockWaitingPeriod.WEEK]),
          stakedAmountForWeek,
        )
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([wallet.account.address, UnlockWaitingPeriod.WEEK12]),
          stakedAmountForWeek12,
        )
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([wallet.account.address, 0]),
          0n,
        )

        assert.equal(
          await BetVotingEscrow.read.stakedWeight([wallet.account.address]),
          stakedAmountForWeek + stakedAmountForWeek12 * 2n,
        )

        assert.deepEqual(
          await BetVotingEscrow.read.stakedRecord([wallet.account.address, UnlockWaitingPeriod.WEEK]),
          {
            account: stakedAmountForWeek === 0n ? zeroAddress : getAddress(wallet.account.address),
            unlockWaitingPeriod: UnlockWaitingPeriod.WEEK,
            amount: stakedAmountForWeek,
          },
        )
        assert.deepEqual(
          await BetVotingEscrow.read.stakedRecord([wallet.account.address, UnlockWaitingPeriod.WEEK12]),
          {
            account: stakedAmountForWeek12 === 0n ? zeroAddress : getAddress(wallet.account.address),
            unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12,
            amount: stakedAmountForWeek12,
          },
        )
      }
    })

    it('#unstake() #unstakedRecords()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      const accounts = [
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12 },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK },
      ]

      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(hacker, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, stakeAmount)
      for (const { wallet, unlockWaitingPeriod } of accounts) {
        await stake(wallet, BetGovToken, BetVotingEscrow, unlockWaitingPeriod, stakeAmount)

        await assert.isRejected(
          unstake(wallet, BetVotingEscrow, 0, stakeAmount),
          'NoStakedRecordFound',
        )
        await assert.isRejected(
          unstake(wallet, BetVotingEscrow, unlockWaitingPeriod, stakeAmount + 1n),
          'StakeInsufficientBalance',
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
          await unstake(wallet, BetVotingEscrow, unlockWaitingPeriod, unstakeAmountArr[i])
          unstakeStartTimeMap[wallet.account.address].push(await time.latest())
        }

        let j = 0
        for (const { wallet, unlockWaitingPeriod } of accounts) {
          assert.equal(
            await BetVotingEscrow.read.balanceOf([wallet.account.address]),
            stakeAmount + stakedAmount,
          )
          assert.equal(
            await BetVotingEscrow.read.stakedAmount([wallet.account.address, unlockWaitingPeriod]),
            stakedAmount,
          )
          assert.deepEqual(
            await BetVotingEscrow.read.stakedRecord([wallet.account.address, unlockWaitingPeriod]),
            {
              account: stakedAmount === 0n ? zeroAddress : getAddress(wallet.account.address),
              unlockWaitingPeriod: unlockWaitingPeriod,
              amount: stakedAmount,
            },
          )
          assert.equal(
            await BetVotingEscrow.read.stakedRecordCount(),
            stakedAmount === 0n ? 2n : 4n,
          )
          assert.deepEqual(
            await BetVotingEscrow.read.unstakedRecords([wallet.account.address, unlockWaitingPeriod]),
            unstakeStartTimeMap[wallet.account.address].map((unstakeStartTime, index) => ({
              account: getAddress(wallet.account.address),
              unlockWaitingPeriod: unlockWaitingPeriod,
              amount: unstakeAmountArr[index],
              unlockTime: BigInt(unstakeStartTime) + Time[unlockWaitingPeriod],
              index: BigInt(index * 2 + j),
            })),
          )
          j++
        }
      }
    })

    it('#restake()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      const accounts = [
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12 },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK },
      ]

      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(hacker, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, stakeAmount)
      for (const { wallet, unlockWaitingPeriod } of accounts) {
        await stake(wallet, BetGovToken, BetVotingEscrow, unlockWaitingPeriod, stakeAmount)
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
        for (const { wallet, unlockWaitingPeriod } of accounts) {
          await unstake(wallet, BetVotingEscrow, unlockWaitingPeriod, unstakeAmountArr[i])
          unstakeStartTimeMap[wallet.account.address].push(await time.latest())
        }
      }

      for (let i = 0; i < length; i++) {
        const stakedAmount = unstakeAmountArr.slice(0, i + 1).reduce((acc, cur) => acc + cur, 0n)
        for (const { wallet } of accounts) {
          await BetVotingEscrow.write.restake([0n], { account: wallet.account })
        }

        let j = 0
        for (const { wallet, unlockWaitingPeriod } of accounts) {
          assert.equal(
            await BetVotingEscrow.read.balanceOf([wallet.account.address]),
            stakeAmount + stakedAmount,
          )
          assert.equal(
            await BetVotingEscrow.read.stakedAmount([wallet.account.address, unlockWaitingPeriod]),
            stakedAmount,
          )
          assert.deepEqual(
            await BetVotingEscrow.read.stakedRecord([wallet.account.address, unlockWaitingPeriod]),
            {
              account: getAddress(wallet.account.address),
              unlockWaitingPeriod: unlockWaitingPeriod,
              amount: stakedAmount,
            },
          )
          assert.equal(
            await BetVotingEscrow.read.stakedRecordCount(),
            4n,
          )
          assert.deepEqual(
            await BetVotingEscrow.read.unstakedRecords([wallet.account.address, unlockWaitingPeriod]),
            unstakeStartTimeMap[wallet.account.address].slice(i + 1).map((unstakeStartTime, index) => ({
              account: getAddress(wallet.account.address),
              unlockWaitingPeriod: unlockWaitingPeriod,
              amount: unstakeAmountArr[i + 1 + index],
              unlockTime: BigInt(unstakeStartTime) + Time[unlockWaitingPeriod],
              index: BigInt(index * 2 + j),
            })),
          )
          j++
        }
      }
    })

    it('#increaseUnlockWaitingPeriod()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)

      const length = 4
      for (let i = 0; i < length; i++) {
        await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([user.account.address, UnlockWaitingPeriod.WEEK]),
          stakeAmount,
        )
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([user.account.address, UnlockWaitingPeriod.WEEK12]),
          stakeAmount * BigInt(i),
        )

        await BetVotingEscrow.write.increaseUnlockWaitingPeriod({ account: user.account })
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([user.account.address, UnlockWaitingPeriod.WEEK]),
          0n,
        )
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([user.account.address, UnlockWaitingPeriod.WEEK12]),
          stakeAmount * BigInt(i + 1),
        )
      }

      await stake(hacker, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.stakedAmount([hacker.account.address, UnlockWaitingPeriod.WEEK]),
        stakeAmount,
      )
      assert.equal(
        await BetVotingEscrow.read.stakedAmount([hacker.account.address, UnlockWaitingPeriod.WEEK12]),
        0n,
      )

      const perAmount = stakeAmount / BigInt(length)
      for (let i = 0; i < length; i++) {
        await BetVotingEscrow.write.increaseUnlockWaitingPeriod([perAmount], { account: hacker.account })
        const stakedAmountForWeek12 = perAmount * BigInt(i + 1)
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([hacker.account.address, UnlockWaitingPeriod.WEEK]),
          stakeAmount - stakedAmountForWeek12,
        )
        assert.equal(
          await BetVotingEscrow.read.stakedAmount([hacker.account.address, UnlockWaitingPeriod.WEEK12]),
          stakedAmountForWeek12,
        )
      }
    })

    it('#withdraw()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, stakeAmount)
      await stake(hacker, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(hacker, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, stakeAmount)

      const unstakeAmount = stakeAmount / 2n
      await unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK, unstakeAmount)
      await unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, unstakeAmount)
      await unstake(hacker, BetVotingEscrow, UnlockWaitingPeriod.WEEK, unstakeAmount)
      await unstake(hacker, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, unstakeAmount)

      await checkBalance(
        async () => {
          await withdraw(user, BetVotingEscrow)
        },
        [
          [user.account.address, BetGovToken.address, 0n],
          [hacker.account.address, BetGovToken.address, 0n],
        ],
      )

      await time.increase(Time[UnlockWaitingPeriod.WEEK])
      await checkBalance(
        async () => {
          await withdraw(user, BetVotingEscrow)
        },
        [
          [user.account.address, BetGovToken.address, unstakeAmount],
          [hacker.account.address, BetGovToken.address, unstakeAmount],
        ],
      )

      await unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK)
      await unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK12)
      await unstake(hacker, BetVotingEscrow, UnlockWaitingPeriod.WEEK)
      await unstake(hacker, BetVotingEscrow, UnlockWaitingPeriod.WEEK12)
      await time.increase(Time[UnlockWaitingPeriod.WEEK12])
      await checkBalance(
        async () => {
          await withdraw(user, BetVotingEscrow)
        },
        [
          [user.account.address, BetGovToken.address, stakeAmount * 2n - unstakeAmount],
          [hacker.account.address, BetGovToken.address, stakeAmount * 2n - unstakeAmount],
        ],
      )
    })

    it('Preventing dust attacks', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      const stakeMinValue = await BetVotingEscrow.read.stakeMinValue()

      await assert.isRejected(
        stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeMinValue - 1n),
        'InvalidAmount',
      )

      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.stakedRecordCount(),
        1n,
      )

      await assert.isRejected(
        unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeMinValue - 1n),
        'InvalidAmount',
      )

      await checkBalance(
        async () => {
          await unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount - stakeMinValue + 1n)
        },
        [
          [user.account.address, BetVotingEscrow.address, -stakeAmount],
        ],
      )

      assert.equal(
        await BetVotingEscrow.read.stakedRecordCount(),
        0n,
      )
    })
  })

  describe('Distribute rewards', () => {
    it('#distribute() #rewards() #claimableRewards()', async () => {
      const {
        DAI,
        BetGovToken,
        BetVotingEscrow,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const accounts = [
        { wallet: owner, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakingRatio: 2n, rewardRatio: 4n },
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakingRatio: 5n, rewardRatio: 10n },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK, stakingRatio: 3n, rewardRatio: 3n },
      ]
      const tokens: [Address, bigint][] = [
        [zeroAddress, parseEther('10')],
        [DAI.address, parseUnits('10000', 18)],
      ]

      for (const { wallet } of accounts) {
        for (const [token] of tokens) {
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await BetVotingEscrow.read.rewards([wallet.account.address])
              : await BetVotingEscrow.read.rewards([wallet.account.address, token]),
            0n,
          )
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await BetVotingEscrow.read.claimableRewards([wallet.account.address])
              : await BetVotingEscrow.read.claimableRewards([wallet.account.address, token]),
            0n,
          )
        }
      }

      for (const [token, amount] of tokens) {
        await distribute(owner, BetVotingEscrow, token, amount)
      }

      for (const { wallet } of accounts) {
        for (const [token] of tokens) {
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await BetVotingEscrow.read.rewards([wallet.account.address])
              : await BetVotingEscrow.read.rewards([wallet.account.address, token]),
            0n,
          )
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await BetVotingEscrow.read.claimableRewards([wallet.account.address])
              : await BetVotingEscrow.read.claimableRewards([wallet.account.address, token]),
            0n,
          )
        }
      }

      // Staking
      const stakingTotalAmount = parseUnits('100000', 18)
      const stakingCount = accounts.reduce((acc, cur) => acc + cur.stakingRatio, 0n)
      for (const { wallet, unlockWaitingPeriod, stakingRatio } of accounts) {
        await stake(wallet, BetGovToken, BetVotingEscrow, unlockWaitingPeriod, stakingTotalAmount * stakingRatio / stakingCount)
      }

      for (const [token, amount] of tokens) {
        await distribute(owner, BetVotingEscrow, token, amount)
      }

      const rewardCount = accounts.reduce((acc, cur) => acc + cur.rewardRatio, 0n)
      for (const { wallet, rewardRatio } of accounts) {
        for (const [token, amount] of tokens) {
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await BetVotingEscrow.read.rewards([wallet.account.address])
              : await BetVotingEscrow.read.rewards([wallet.account.address, token]),
            amount * rewardRatio / rewardCount,
          )
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await BetVotingEscrow.read.claimableRewards([wallet.account.address])
              : await BetVotingEscrow.read.claimableRewards([wallet.account.address, token]),
            amount * rewardRatio / rewardCount,
          )
        }
      }
    })

    it('#claim()', async () => {
      const {
        DAI,
        BetGovToken,
        BetVotingEscrow,
        owner,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const accounts = [
        { wallet: owner, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakingRatio: 2n, rewardRatio: 4n },
        { wallet: user, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12, stakingRatio: 5n, rewardRatio: 10n },
        { wallet: hacker, unlockWaitingPeriod: UnlockWaitingPeriod.WEEK, stakingRatio: 3n, rewardRatio: 3n },
      ]
      const tokens: [Address, bigint][] = [
        [zeroAddress, parseEther('10')],
        [DAI.address, parseUnits('10000', 18)],
      ]

      // Staking
      const stakingTotalAmount = parseUnits('100000', 18)
      const stakingCount = accounts.reduce((acc, cur) => acc + cur.stakingRatio, 0n)
      for (const { wallet, unlockWaitingPeriod, stakingRatio } of accounts) {
        await stake(wallet, BetGovToken, BetVotingEscrow, unlockWaitingPeriod, stakingTotalAmount * stakingRatio / stakingCount)
      }

      for (const { wallet } of accounts) {
        for (const [token] of tokens) {
          await assert.isRejected(
            isAddressEqual(zeroAddress, token)
              ? BetVotingEscrow.write.claim({ account: wallet.account })
              : BetVotingEscrow.write.claim([token], { account: wallet.account }),
            'NoClaimableRewards',
          )
        }
      }

      for (const [token, amount] of tokens) {
        await distribute(owner, BetVotingEscrow, token, amount)
      }

      const rewardCount = accounts.reduce((acc, cur) => acc + cur.rewardRatio, 0n)
      for (const { wallet, rewardRatio } of accounts) {
        for (const [token, amount] of tokens) {
          await checkBalance(
            async () => {
              isAddressEqual(zeroAddress, token)
                ? await BetVotingEscrow.write.claim({ account: wallet.account })
                : await BetVotingEscrow.write.claim([token], { account: wallet.account })
            },
            [
              [wallet.account.address, token, amount * rewardRatio / rewardCount],
            ],
          )
        }
      }

      for (const { wallet, rewardRatio } of accounts) {
        for (const [token, amount] of tokens) {
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await BetVotingEscrow.read.rewards([wallet.account.address])
              : await BetVotingEscrow.read.rewards([wallet.account.address, token]),
            amount * rewardRatio / rewardCount,
          )
          assert.equal(
            isAddressEqual(zeroAddress, token)
              ? await BetVotingEscrow.read.claimableRewards([wallet.account.address])
              : await BetVotingEscrow.read.claimableRewards([wallet.account.address, token]),
            0n,
          )
        }
      }
    })
  })

  describe('Fixable', () => {
    it('#fix()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )

      const fixedAmount = parseUnits('10000', 18)
      const TestBet = await viem.deployContract('TestBet', [
        0,
        zeroAddress,
        BetVotingEscrow.address,
      ])

      await assert.isRejected(
        BetVotingEscrow.write.fix([user.account.address, fixedAmount], { account: owner.account }),
        'UnauthorizedAccess',
      )
      await assert.isRejected(
        TestBet.write.functionCall(
          [
            BetVotingEscrow.address,
            encodeFunctionData({
              abi: BetVotingEscrow.abi,
              functionName: 'fix',
              args: [user.account.address, fixedAmount],
            }),
          ],
          { account: owner.account },
        ),
        'ERC20InsufficientAllowance',
      )

      await BetVotingEscrow.write.approve([TestBet.address, fixedAmount], { account: user.account })
      await assert.isRejected(
        TestBet.write.functionCall(
          [
            BetVotingEscrow.address,
            encodeFunctionData({
              abi: BetVotingEscrow.abi,
              functionName: 'fix',
              args: [user.account.address, fixedAmount + 1n],
            }),
          ],
          { account: owner.account },
        ),
        'ERC20InsufficientAllowance',
      )

      await TestBet.write.functionCall(
        [
          BetVotingEscrow.address,
          encodeFunctionData({
            abi: BetVotingEscrow.abi,
            functionName: 'fix',
            args: [user.account.address, fixedAmount],
          }),
        ],
        { account: owner.account },
      )
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount - fixedAmount,
      )
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address, true]),
        stakeAmount,
      )

      // Unstake should fail
      await assert.isRejected(
        unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount),
        'VoteInsufficientAvailableBalance',
      )
    })

    it('#unfix()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)

      const fixedAmount = parseUnits('10000', 18)
      const TestBet = await viem.deployContract('TestBet', [
        0,
        zeroAddress,
        BetVotingEscrow.address,
      ])

      await BetVotingEscrow.write.approve([TestBet.address, fixedAmount], { account: user.account })
      await TestBet.write.functionCall(
        [
          BetVotingEscrow.address,
          encodeFunctionData({
            abi: BetVotingEscrow.abi,
            functionName: 'fix',
            args: [user.account.address, fixedAmount],
          }),
        ],
        { account: owner.account },
      )

      await assert.isRejected(
        BetVotingEscrow.write.unfix([user.account.address, fixedAmount], { account: owner.account }),
        'UnauthorizedAccess',
      )
      await assert.isRejected(
        TestBet.write.functionCall(
          [
            BetVotingEscrow.address,
            encodeFunctionData({
              abi: BetVotingEscrow.abi,
              functionName: 'unfix',
              args: [user.account.address, fixedAmount + 1n],
            }),
          ],
          { account: owner.account },
        ),
        'VoteInsufficientFixedAllowance',
      )

      await TestBet.write.functionCall(
        [
          BetVotingEscrow.address,
          encodeFunctionData({
            abi: BetVotingEscrow.abi,
            functionName: 'unfix',
            args: [user.account.address, fixedAmount],
          }),
        ],
        { account: owner.account },
      )
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address, true]),
        stakeAmount,
      )

      // Unstake should succeed.
      await unstake(user, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        0n,
      )
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address, true]),
        0n,
      )
    })

    it('#confiscate()', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)

      const fixedAmount = parseUnits('10000', 18)
      const TestBet = await viem.deployContract('TestBet', [
        0,
        zeroAddress,
        BetVotingEscrow.address,
      ])

      await BetVotingEscrow.write.approve([TestBet.address, fixedAmount], { account: user.account })
      await TestBet.write.functionCall(
        [
          BetVotingEscrow.address,
          encodeFunctionData({
            abi: BetVotingEscrow.abi,
            functionName: 'fix',
            args: [user.account.address, fixedAmount],
          }),
        ],
        { account: owner.account },
      )

      await assert.isRejected(
        BetVotingEscrow.write.confiscate([user.account.address, fixedAmount, owner.account.address], { account: owner.account }),
        'UnauthorizedAccess',
      )
      await assert.isRejected(
        TestBet.write.functionCall(
          [
            BetVotingEscrow.address,
            encodeFunctionData({
              abi: BetVotingEscrow.abi,
              functionName: 'confiscate',
              args: [user.account.address, fixedAmount + 1n, owner.account.address],
            }),
          ],
          { account: owner.account },
        ),
        'VoteInsufficientFixedAllowance',
      )

      await checkBalance(
        async () => {
          await TestBet.write.functionCall(
            [
              BetVotingEscrow.address,
              encodeFunctionData({
                abi: BetVotingEscrow.abi,
                functionName: 'confiscate',
                args: [user.account.address, fixedAmount, owner.account.address],
              }),
            ],
            { account: owner.account },
          )
        },
        [
          [owner.account.address, BetGovToken.address, fixedAmount],
        ],
      )
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount - fixedAmount,
      )
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address, true]),
        stakeAmount - fixedAmount,
      )
    })
  })

  describe('Transfer', () => {
    it('#transfer() is unable to transfer', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)

      await assert.isRejected(
        BetVotingEscrow.write.transfer([hacker.account.address, stakeAmount], { account: user.account }),
        'VoteNotTransferable',
      )
    })

    it('#transferFrom() is unable to transfer', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)

      await BetVotingEscrow.write.approve([hacker.account.address, stakeAmount], { account: user.account })
      await assert.isRejected(
        // @ts-expect-error
        BetVotingEscrow.write.transferFrom([user.account.address, hacker.account.address, stakeAmount], { account: hacker.account }),
        'VoteNotTransferable',
      )
    })

    it('#transfer() is able to decide', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)

      const decidedAmount = parseUnits('10000', 18)

      {
        const TestBet = await viem.deployContract('TestBet', [
          0,
          zeroAddress,
          BetVotingEscrow.address,
        ])
        await assert.isRejected(
          erc20Transfer(user, BetVotingEscrow.address, TestBet.address, decidedAmount),
          'InvalidStatus',
        )
        const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
        await assert.isRejected(
          erc20Transfer(user, BetVotingEscrow.address, TestBetOption.address, decidedAmount),
          'InvalidStatus',
        )
      }

      {
        const TestBet = await viem.deployContract('TestBet', [
          1,
          zeroAddress,
          BetVotingEscrow.address,
        ])
        await assert.isRejected(
          erc20Transfer(hacker, BetVotingEscrow.address, TestBet.address, decidedAmount),
          'InvalidStatus',
        )
        await assert.isRejected(
          erc20Transfer(user, BetVotingEscrow.address, TestBet.address, stakeAmount + 1n),
          'InvalidStatus',
        )
        const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
        await assert.isRejected(
          erc20Transfer(hacker, BetVotingEscrow.address, TestBetOption.address, decidedAmount),
          'VoteConditionsNotMet',
        )
        await assert.isRejected(
          erc20Transfer(user, BetVotingEscrow.address, TestBetOption.address, stakeAmount + 1n),
          'VoteInsufficientAvailableBalance',
        )

        assert.equal(await TestBetOption.read.decided(), false)
        await checkBalance(
          async () => {
            await erc20Transfer(user, BetVotingEscrow.address, TestBetOption.address, decidedAmount)
          },
          [
            [user.account.address, BetVotingEscrow.address, -decidedAmount],
          ],
        )
        assert.equal(await TestBetOption.read.decided(), true)
      }
    })

    it('#transfer() is able to arbitrate', async () => {
      const {
        BetGovToken,
        BetVotingEscrow,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK12, stakeAmount)
      await stake(hacker, BetGovToken, BetVotingEscrow, UnlockWaitingPeriod.WEEK, stakeAmount)

      {
        const TestBet = await viem.deployContract('TestBet', [
          2,
          zeroAddress,
          BetVotingEscrow.address,
        ])
        await assert.isRejected(
          erc20Transfer(user, BetVotingEscrow.address, TestBet.address, 1n),
          'InvalidStatus',
        )
        const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
        await assert.isRejected(
          erc20Transfer(user, BetVotingEscrow.address, TestBetOption.address, 1n),
          'InvalidStatus',
        )
      }

      {
        const TestBet = await viem.deployContract('TestBet', [
          3,
          zeroAddress,
          BetVotingEscrow.address,
        ])
        await assert.isRejected(
          erc20Transfer(hacker, BetVotingEscrow.address, TestBet.address, 1n),
          'VoteConditionsNotMet',
        )
        const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
        await assert.isRejected(
          erc20Transfer(hacker, BetVotingEscrow.address, TestBetOption.address, 1n),
          'VoteConditionsNotMet',
        )

        assert.equal(await TestBet.read.arbitrated(), false)
        await erc20Transfer(user, BetVotingEscrow.address, TestBet.address, 1n)
        assert.equal(await TestBet.read.arbitrated(), true)

        assert.equal(await TestBetOption.read.arbitrated(), false)
        await erc20Transfer(user, BetVotingEscrow.address, TestBetOption.address, 1n)
        assert.equal(await TestBetOption.read.arbitrated(), true)
      }
    })
  })

  describe('Level', () => {
    it('#level() #levelUp() #levelDown()', async () => {
      const {
        BetVotingEscrow,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const TestBetManager = await viem.deployContract('TestBetManager')
      await BetVotingEscrow.write.setBetManager([TestBetManager.address], { account: owner.account })
      const TestBet = await viem.deployContract('TestBet', [
        0,
        zeroAddress,
        BetVotingEscrow.address,
      ])
      const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
      await TestBetManager.write.setBet([TestBet.address], { account: owner.account })

      const levelUp = (unauthorized: boolean = false) => {
        return (unauthorized ? TestBetOption.write.functionCall : TestBet.write.functionCall)(
          [
            BetVotingEscrow.address,
            encodeFunctionData({
              abi: BetVotingEscrow.abi,
              functionName: 'levelUp',
              args: [user.account.address],
            }),
          ],
          { account: owner.account },
        )
      }

      const levelDown = (unauthorized: boolean = false) => {
        return (unauthorized ? TestBetOption.write.functionCall : TestBet.write.functionCall)(
          [
            BetVotingEscrow.address,
            encodeFunctionData({
              abi: BetVotingEscrow.abi,
              functionName: 'levelDown',
              args: [user.account.address],
            }),
          ],
          { account: owner.account },
        )
      }

      assert.equal(await BetVotingEscrow.read.level([user.account.address]), 0n)
      await assert.isRejected(levelUp(true), 'UnauthorizedAccess')

      for (let i = 0; i < 4; i++) {
        await levelUp()
      }
      assert.equal(await BetVotingEscrow.read.level([user.account.address]), 4n)

      await assert.isRejected(levelDown(true), 'UnauthorizedAccess')

      await levelDown()
      assert.equal(await BetVotingEscrow.read.level([user.account.address]), 1n)

      await levelDown()
      assert.equal(await BetVotingEscrow.read.level([user.account.address]), 0n)
    })
  })
})
