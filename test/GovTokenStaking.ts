import { loadFixture, time } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  getAddress,
  parseUnits,
  zeroAddress,
} from 'viem'
import {
  claimTestTokens,
  deployGovToken,
  deployTestTokens,
} from './common'
import {
  UnlockWaitingPeriod,
  deployGovTokenStaking,
  stake,
  unstake,
  withdraw,
} from './common/staking'
import { deployBetVotingEscrow } from './common/vote'
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

    const GovToken = await deployGovToken()
    const BetVotingEscrow = await deployBetVotingEscrow()
    const GovTokenStaking = await deployGovTokenStaking(GovToken.address, BetVotingEscrow.address)

    await BetVotingEscrow.write.setGovTokenStaking([GovTokenStaking.address])
    await GovToken.write.transfer([user.account.address, parseUnits('1000000', 18)])
    await GovToken.write.transfer([hacker.account.address, parseUnits('1000000', 18)])

    return {
      ...testTokens,
      BetVotingEscrow,
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
        GovTokenStaking,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        GovTokenStaking.write.setGovToken([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await GovTokenStaking.write.setGovToken([zeroAddress], { account: owner.account })
      assert.equal(
        await GovTokenStaking.read.govToken(),
        zeroAddress,
      )
    })

    it('#voteToken() #setVoteToken()', async () => {
      const {
        GovTokenStaking,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        GovTokenStaking.write.setVoteToken([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await GovTokenStaking.write.setVoteToken([zeroAddress], { account: owner.account })
      assert.equal(
        await GovTokenStaking.read.voteToken(),
        zeroAddress,
      )
    })
  })

  describe('Staking', async () => {
    it('#stake() #stakedRecords()', async () => {
      const {
        GovToken,
        GovTokenStaking,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)

      await assert.isRejected(
        stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12 + 1, stakeAmount),
        'Transaction reverted and Hardhat couldn\'t infer the reason.',
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
        accounts.reduce((acc, cur) => acc + cur.stakedAmountForWeek + cur.stakedAmountForWeek12 * 2n, 0n),
      )
      assert.equal(
        await GovTokenStaking.read.stakedRecordCount(),
        3n,
      )
      assert.equal(
        await GovTokenStaking.read.stakedRecordCount([UnlockWaitingPeriod.WEEK]),
        2n,
      )
      assert.equal(
        await GovTokenStaking.read.stakedRecordCount([UnlockWaitingPeriod.WEEK12]),
        1n,
      )
      assert.deepEqual(
        await GovTokenStaking.read.stakedRecords(),
        accounts.reduce((acc: { account: Address, unlockWaitingPeriod: number, amount: bigint }[], cur) => {
          if (cur.stakedAmountForWeek !== 0n) {
            acc.push({
              account: getAddress(cur.wallet.account.address),
              unlockWaitingPeriod: UnlockWaitingPeriod.WEEK,
              amount: cur.stakedAmountForWeek,
            })
          }
          if (cur.stakedAmountForWeek12 !== 0n) {
            acc.push({
              account: getAddress(cur.wallet.account.address),
              unlockWaitingPeriod: UnlockWaitingPeriod.WEEK12,
              amount: cur.stakedAmountForWeek12,
            })
          }
          return acc
        }, []),
      )

      for (const { wallet, stakedAmountForWeek, stakedAmountForWeek12 } of accounts) {
        assert.equal(
          await GovTokenStaking.read.isStaked([wallet.account.address]),
          true,
        )
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
          stakedAmountForWeek + stakedAmountForWeek12 * 2n,
        )

        assert.deepEqual(
          await GovTokenStaking.read.stakedRecord([wallet.account.address, UnlockWaitingPeriod.WEEK]),
          {
            account: stakedAmountForWeek === 0n ? zeroAddress : getAddress(wallet.account.address),
            unlockWaitingPeriod: UnlockWaitingPeriod.WEEK,
            amount: stakedAmountForWeek,
          },
        )
        assert.deepEqual(
          await GovTokenStaking.read.stakedRecord([wallet.account.address, UnlockWaitingPeriod.WEEK12]),
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
        GovToken,
        GovTokenStaking,
        BetVotingEscrow,
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

        let j = 0
        for (const { wallet, unlockWaitingPeriod } of accounts) {
          assert.equal(
            await BetVotingEscrow.read.balanceOf([wallet.account.address]),
            stakeAmount + stakedAmount,
          )
          assert.equal(
            await GovTokenStaking.read.stakedAmount([wallet.account.address, unlockWaitingPeriod]),
            stakedAmount,
          )
          assert.deepEqual(
            await GovTokenStaking.read.stakedRecord([wallet.account.address, unlockWaitingPeriod]),
            {
              account: stakedAmount === 0n ? zeroAddress : getAddress(wallet.account.address),
              unlockWaitingPeriod: unlockWaitingPeriod,
              amount: stakedAmount,
            },
          )
          assert.equal(
            await GovTokenStaking.read.stakedRecordCount(),
            stakedAmount === 0n ? 2n : 4n,
          )
          assert.deepEqual(
            await GovTokenStaking.read.unstakedRecords([wallet.account.address, unlockWaitingPeriod]),
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
        GovToken,
        GovTokenStaking,
        BetVotingEscrow,
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
        await GovTokenStaking.read.stakedRecordCount(),
        4n,
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
        await GovTokenStaking.read.stakedRecordCount(),
        2n,
      )

      for (let i = 0; i < length; i++) {
        const stakedAmount = unstakeAmountArr.slice(0, i + 1).reduce((acc, cur) => acc + cur, 0n)
        for (const { wallet } of accounts) {
          await GovTokenStaking.write.restake([0n], { account: wallet.account })
        }

        let j = 0
        for (const { wallet, unlockWaitingPeriod } of accounts) {
          assert.equal(
            await BetVotingEscrow.read.balanceOf([wallet.account.address]),
            stakeAmount + stakedAmount,
          )
          assert.equal(
            await GovTokenStaking.read.stakedAmount([wallet.account.address, unlockWaitingPeriod]),
            stakedAmount,
          )
          assert.deepEqual(
            await GovTokenStaking.read.stakedRecord([wallet.account.address, unlockWaitingPeriod]),
            {
              account: getAddress(wallet.account.address),
              unlockWaitingPeriod: unlockWaitingPeriod,
              amount: stakedAmount,
            },
          )
          assert.equal(
            await GovTokenStaking.read.stakedRecordCount(),
            4n,
          )
          assert.deepEqual(
            await GovTokenStaking.read.unstakedRecords([wallet.account.address, unlockWaitingPeriod]),
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

        assert.equal(
          await GovTokenStaking.read.stakedRecordCount(),
          4n,
        )
      }
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
          'Transaction reverted and Hardhat couldn\'t infer the reason.',
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
          'Transaction reverted and Hardhat couldn\'t infer the reason.',
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
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)

      const unstakeAmount = stakeAmount / 2n
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK, unstakeAmount)
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK12, unstakeAmount)
      await unstake(hacker, GovTokenStaking, UnlockWaitingPeriod.WEEK, unstakeAmount)
      await unstake(hacker, GovTokenStaking, UnlockWaitingPeriod.WEEK12, unstakeAmount)

      await checkBalance(
        async () => {
          await withdraw(user, GovTokenStaking)
        },
        [
          [user.account.address, GovToken.address, 0n],
          [hacker.account.address, GovToken.address, 0n],
        ],
      )

      await time.increase(Time[UnlockWaitingPeriod.WEEK])
      await checkBalance(
        async () => {
          await withdraw(user, GovTokenStaking)
        },
        [
          [user.account.address, GovToken.address, unstakeAmount],
          [hacker.account.address, GovToken.address, unstakeAmount],
        ],
      )

      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK)
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK12)
      await unstake(hacker, GovTokenStaking, UnlockWaitingPeriod.WEEK)
      await unstake(hacker, GovTokenStaking, UnlockWaitingPeriod.WEEK12)
      await time.increase(Time[UnlockWaitingPeriod.WEEK12])
      await checkBalance(
        async () => {
          await withdraw(user, GovTokenStaking)
        },
        [
          [user.account.address, GovToken.address, stakeAmount * 2n - unstakeAmount],
          [hacker.account.address, GovToken.address, stakeAmount * 2n - unstakeAmount],
        ],
      )
    })

    it('Preventing dust attacks', async () => {
      const {
        GovToken,
        GovTokenStaking,
        BetVotingEscrow,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      const stakeMinValue = await GovTokenStaking.read.stakeMinValue()

      await assert.isRejected(
        stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue - 1n),
        'InvalidAmount',
      )

      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await GovTokenStaking.read.stakedRecordCount(),
        1n,
      )

      await assert.isRejected(
        unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeMinValue - 1n),
        'InvalidAmount',
      )

      await checkBalance(
        async () => {
          await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount - stakeMinValue + 1n)
        },
        [
          [user.account.address, BetVotingEscrow.address, -stakeAmount],
        ],
      )

      assert.equal(
        await GovTokenStaking.read.stakedRecordCount(),
        0n,
      )
    })
  })
})
