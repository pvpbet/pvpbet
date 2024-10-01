import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  encodeFunctionData,
  getAddress,
  parseUnits,
  zeroAddress,
} from 'viem'
import { erc20Transfer } from '../utils'
import {
  claimTestTokens,
  deployGovToken,
  deployTestTokens,
} from './common'
import { deployBetChip } from './common/chip'
import {
  UnlockWaitingPeriod,
  deployGovTokenStaking,
  stake,
  unstake,
} from './common/staking'
import { deployBetVotingEscrow } from './common/vote'
import { checkBalance } from './asserts'
import { testReceivable } from './asserts/Receivable'
import { testWithdrawable } from './asserts/Withdrawable'
import type { ContractTypes } from '../types'

describe('BetVotingEscrow', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const testTokens = await deployTestTokens()
    await claimTestTokens(owner, testTokens)

    const { USDC } = testTokens
    const BetChip = await deployBetChip(USDC.address)
    const BetVotingEscrow = await deployBetVotingEscrow()
    const GovToken = await deployGovToken()
    const GovTokenStaking = await deployGovTokenStaking(GovToken.address, BetChip.address, BetVotingEscrow.address)

    await BetVotingEscrow.write.setGovTokenStaking([GovTokenStaking.address])
    await GovToken.write.transfer([user.account.address, parseUnits('1000000', 18)])
    await GovToken.write.transfer([hacker.account.address, parseUnits('1000000', 18)])

    return {
      ...testTokens,
      BetChip,
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
    it('#govTokenStaking() #setGovTokenStaking()', async () => {
      const {
        BetVotingEscrow,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetVotingEscrow.write.setGovTokenStaking([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetVotingEscrow.write.setGovTokenStaking([zeroAddress], { account: owner.account })
      assert.equal(
        await BetVotingEscrow.read.govTokenStaking(),
        zeroAddress,
      )
    })
  })

  describe('Mint or Burn through staking', async () => {
    it('#balanceOf()', async () => {
      const {
        BetVotingEscrow,
        GovToken,
        GovTokenStaking,
        user,
      } = await loadFixture(deployFixture)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        0n,
      )

      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )

      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount * 2n,
      )

      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )

      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK12)
      assert.equal(
        await BetVotingEscrow.read.balanceOf([user.account.address]),
        0n,
      )
    })

    it('#isAbleToDecide() #isAbleToArbitrate()', async () => {
      const {
        BetVotingEscrow,
        GovToken,
        GovTokenStaking,
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
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.isAbleToDecide([user.account.address]),
        true,
      )
      assert.equal(
        await BetVotingEscrow.read.isAbleToArbitrate([user.account.address]),
        false,
      )

      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      assert.equal(
        await BetVotingEscrow.read.isAbleToDecide([user.account.address]),
        true,
      )
      assert.equal(
        await BetVotingEscrow.read.isAbleToArbitrate([user.account.address]),
        true,
      )
    })
  })

  describe('Fixable', () => {
    it('#fix()', async () => {
      const {
        BetVotingEscrow,
        GovToken,
        GovTokenStaking,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
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
        unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount),
        'VoteInsufficientAvailableBalance',
      )
    })

    it('#unfix()', async () => {
      const {
        BetVotingEscrow,
        GovToken,
        GovTokenStaking,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)

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
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
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
        BetVotingEscrow,
        GovToken,
        GovTokenStaking,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)

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
          [owner.account.address, GovToken.address, fixedAmount],
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
        BetVotingEscrow,
        GovToken,
        GovTokenStaking,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)

      await assert.isRejected(
        BetVotingEscrow.write.transfer([hacker.account.address, stakeAmount], { account: user.account }),
        'VoteNotTransferable',
      )
    })

    it('#transferFrom() is unable to transfer', async () => {
      const {
        BetVotingEscrow,
        GovToken,
        GovTokenStaking,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)

      await BetVotingEscrow.write.approve([hacker.account.address, stakeAmount], { account: user.account })
      await assert.isRejected(
        // @ts-expect-error
        BetVotingEscrow.write.transferFrom([user.account.address, hacker.account.address, stakeAmount], { account: hacker.account }),
        'VoteNotTransferable',
      )
    })

    it('#transfer() is able to decide', async () => {
      const {
        BetVotingEscrow,
        GovToken,
        GovTokenStaking,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)

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
          'VotingConditionsNotMet',
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
        BetVotingEscrow,
        GovToken,
        GovTokenStaking,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      await stake(hacker, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)

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
          'VotingConditionsNotMet',
        )
        const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
        await assert.isRejected(
          erc20Transfer(hacker, BetVotingEscrow.address, TestBetOption.address, 1n),
          'VotingConditionsNotMet',
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

  testReceivable(async () => {
    const { BetVotingEscrow, owner } = await loadFixture(deployFixture)
    return {
      Receivable: BetVotingEscrow as unknown as ContractTypes['Receivable'],
      owner,
    }
  })

  testWithdrawable(async () => {
    const { BetVotingEscrow, owner } = await loadFixture(deployFixture)
    return {
      Withdrawable: BetVotingEscrow as unknown as ContractTypes['Withdrawable'],
      owner,
    }
  })
})
