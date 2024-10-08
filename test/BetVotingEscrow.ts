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
import {
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
import { checkBalance } from './asserts'

describe('VotingEscrow', () => {
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
        VotingEscrow,
        owner,
      } = await loadFixture(deployFixture)
      assert.equal(
        await VotingEscrow.read.owner(),
        getAddress(owner.account.address),
      )
    })

    it('#transferOwnership()', async () => {
      const {
        VotingEscrow,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        VotingEscrow.write.transferOwnership([hacker.account.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await VotingEscrow.write.transferOwnership([hacker.account.address], { account: owner.account })
      assert.equal(
        await VotingEscrow.read.owner(),
        getAddress(hacker.account.address),
      )
    })
  })

  describe('Config contracts', () => {
    it('#govTokenStaking() #setGovTokenStaking()', async () => {
      const {
        VotingEscrow,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        VotingEscrow.write.setGovTokenStaking([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await VotingEscrow.write.setGovTokenStaking([zeroAddress], { account: owner.account })
      assert.equal(
        await VotingEscrow.read.govTokenStaking(),
        zeroAddress,
      )
    })
  })

  describe('Mint or Burn through staking', async () => {
    it('#balanceOf()', async () => {
      const {
        VotingEscrow,
        GovToken,
        GovTokenStaking,
        user,
      } = await loadFixture(deployFixture)
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address]),
        0n,
      )

      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )

      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount * 2n,
      )

      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK)
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )

      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK12)
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address]),
        0n,
      )
    })

    it('#isAbleToDecide() #isAbleToArbitrate()', async () => {
      const {
        VotingEscrow,
        GovToken,
        GovTokenStaking,
        user,
      } = await loadFixture(deployFixture)
      assert.equal(
        await VotingEscrow.read.isAbleToDecide([user.account.address]),
        false,
      )
      assert.equal(
        await VotingEscrow.read.isAbleToArbitrate([user.account.address]),
        false,
      )

      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await VotingEscrow.read.isAbleToDecide([user.account.address]),
        true,
      )
      assert.equal(
        await VotingEscrow.read.isAbleToArbitrate([user.account.address]),
        false,
      )

      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK12, stakeAmount)
      assert.equal(
        await VotingEscrow.read.isAbleToDecide([user.account.address]),
        true,
      )
      assert.equal(
        await VotingEscrow.read.isAbleToArbitrate([user.account.address]),
        true,
      )
    })
  })

  describe('Fixable', () => {
    it('#fix()', async () => {
      const {
        VotingEscrow,
        GovToken,
        GovTokenStaking,
        owner,
        user,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )

      const fixedAmount = parseUnits('10000', 18)
      const TestBet = await viem.deployContract('TestBet', [
        0,
        zeroAddress,
        VotingEscrow.address,
      ])

      await assert.isRejected(
        VotingEscrow.write.fix([user.account.address, fixedAmount], { account: owner.account }),
        'UnauthorizedAccess',
      )
      await assert.isRejected(
        TestBet.write.functionCall(
          [
            VotingEscrow.address,
            encodeFunctionData({
              abi: VotingEscrow.abi,
              functionName: 'fix',
              args: [user.account.address, fixedAmount],
            }),
          ],
          { account: owner.account },
        ),
        'ERC20InsufficientAllowance',
      )

      await VotingEscrow.write.approve([TestBet.address, fixedAmount], { account: user.account })
      await assert.isRejected(
        TestBet.write.functionCall(
          [
            VotingEscrow.address,
            encodeFunctionData({
              abi: VotingEscrow.abi,
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
          VotingEscrow.address,
          encodeFunctionData({
            abi: VotingEscrow.abi,
            functionName: 'fix',
            args: [user.account.address, fixedAmount],
          }),
        ],
        { account: owner.account },
      )
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount - fixedAmount,
      )
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address, true]),
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
        VotingEscrow,
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
        VotingEscrow.address,
      ])

      await VotingEscrow.write.approve([TestBet.address, fixedAmount], { account: user.account })
      await TestBet.write.functionCall(
        [
          VotingEscrow.address,
          encodeFunctionData({
            abi: VotingEscrow.abi,
            functionName: 'fix',
            args: [user.account.address, fixedAmount],
          }),
        ],
        { account: owner.account },
      )

      await assert.isRejected(
        VotingEscrow.write.unfix([user.account.address, fixedAmount], { account: owner.account }),
        'UnauthorizedAccess',
      )
      await assert.isRejected(
        TestBet.write.functionCall(
          [
            VotingEscrow.address,
            encodeFunctionData({
              abi: VotingEscrow.abi,
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
          VotingEscrow.address,
          encodeFunctionData({
            abi: VotingEscrow.abi,
            functionName: 'unfix',
            args: [user.account.address, fixedAmount],
          }),
        ],
        { account: owner.account },
      )
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount,
      )
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address, true]),
        stakeAmount,
      )

      // Unstake should succeed.
      await unstake(user, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address]),
        0n,
      )
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address, true]),
        0n,
      )
    })

    it('#confiscate()', async () => {
      const {
        VotingEscrow,
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
        VotingEscrow.address,
      ])

      await VotingEscrow.write.approve([TestBet.address, fixedAmount], { account: user.account })
      await TestBet.write.functionCall(
        [
          VotingEscrow.address,
          encodeFunctionData({
            abi: VotingEscrow.abi,
            functionName: 'fix',
            args: [user.account.address, fixedAmount],
          }),
        ],
        { account: owner.account },
      )

      await assert.isRejected(
        VotingEscrow.write.confiscate([user.account.address, fixedAmount, owner.account.address], { account: owner.account }),
        'UnauthorizedAccess',
      )
      await assert.isRejected(
        TestBet.write.functionCall(
          [
            VotingEscrow.address,
            encodeFunctionData({
              abi: VotingEscrow.abi,
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
              VotingEscrow.address,
              encodeFunctionData({
                abi: VotingEscrow.abi,
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
        await VotingEscrow.read.balanceOf([user.account.address]),
        stakeAmount - fixedAmount,
      )
      assert.equal(
        await VotingEscrow.read.balanceOf([user.account.address, true]),
        stakeAmount - fixedAmount,
      )
    })
  })

  describe('Transfer', () => {
    it('#transfer() is unable to transfer', async () => {
      const {
        VotingEscrow,
        GovToken,
        GovTokenStaking,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)

      await assert.isRejected(
        VotingEscrow.write.transfer([hacker.account.address, stakeAmount], { account: user.account }),
        'VoteNotTransferable',
      )
    })

    it('#transferFrom() is unable to transfer', async () => {
      const {
        VotingEscrow,
        GovToken,
        GovTokenStaking,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const stakeAmount = parseUnits('80000', 18)
      await stake(user, GovToken, GovTokenStaking, UnlockWaitingPeriod.WEEK, stakeAmount)

      await VotingEscrow.write.approve([hacker.account.address, stakeAmount], { account: user.account })
      await assert.isRejected(
        // @ts-expect-error
        VotingEscrow.write.transferFrom([user.account.address, hacker.account.address, stakeAmount], { account: hacker.account }),
        'VoteNotTransferable',
      )
    })

    it('#transfer() is able to decide', async () => {
      const {
        VotingEscrow,
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
          VotingEscrow.address,
        ])
        await assert.isRejected(
          erc20Transfer(user, VotingEscrow.address, TestBet.address, decidedAmount),
          'InvalidStatus',
        )
        const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
        await assert.isRejected(
          erc20Transfer(user, VotingEscrow.address, TestBetOption.address, decidedAmount),
          'InvalidStatus',
        )
      }

      {
        const TestBet = await viem.deployContract('TestBet', [
          1,
          zeroAddress,
          VotingEscrow.address,
        ])
        await assert.isRejected(
          erc20Transfer(hacker, VotingEscrow.address, TestBet.address, decidedAmount),
          'InvalidStatus',
        )
        await assert.isRejected(
          erc20Transfer(user, VotingEscrow.address, TestBet.address, stakeAmount + 1n),
          'InvalidStatus',
        )
        const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
        await assert.isRejected(
          erc20Transfer(hacker, VotingEscrow.address, TestBetOption.address, decidedAmount),
          'VotingConditionsNotMet',
        )
        await assert.isRejected(
          erc20Transfer(user, VotingEscrow.address, TestBetOption.address, stakeAmount + 1n),
          'VoteInsufficientAvailableBalance',
        )

        assert.equal(await TestBetOption.read.decided(), false)
        await checkBalance(
          async () => {
            await erc20Transfer(user, VotingEscrow.address, TestBetOption.address, decidedAmount)
          },
          [
            [user.account.address, VotingEscrow.address, -decidedAmount],
          ],
        )
        assert.equal(await TestBetOption.read.decided(), true)
      }
    })

    it('#transfer() is able to arbitrate', async () => {
      const {
        VotingEscrow,
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
          VotingEscrow.address,
        ])
        await assert.isRejected(
          erc20Transfer(user, VotingEscrow.address, TestBet.address, 1n),
          'InvalidStatus',
        )
        const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
        await assert.isRejected(
          erc20Transfer(user, VotingEscrow.address, TestBetOption.address, 1n),
          'InvalidStatus',
        )
      }

      {
        const TestBet = await viem.deployContract('TestBet', [
          3,
          zeroAddress,
          VotingEscrow.address,
        ])
        await assert.isRejected(
          erc20Transfer(hacker, VotingEscrow.address, TestBet.address, 1n),
          'VotingConditionsNotMet',
        )
        const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
        await assert.isRejected(
          erc20Transfer(hacker, VotingEscrow.address, TestBetOption.address, 1n),
          'VotingConditionsNotMet',
        )

        assert.equal(await TestBet.read.arbitrated(), false)
        await erc20Transfer(user, VotingEscrow.address, TestBet.address, 1n)
        assert.equal(await TestBet.read.arbitrated(), true)

        assert.equal(await TestBetOption.read.arbitrated(), false)
        await erc20Transfer(user, VotingEscrow.address, TestBetOption.address, 1n)
        assert.equal(await TestBetOption.read.arbitrated(), true)
      }
    })
  })
})
