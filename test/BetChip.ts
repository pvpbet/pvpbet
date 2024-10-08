import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  parseUnits,
  zeroAddress,
} from 'viem'
import { erc20Transfer } from '../utils'
import {
  claimTestTokens,
  deployTestTokens,
} from './common'
import {
  buyChip,
  createBetChip,
  deployBetChipManager,
} from './common/chip'
import { checkBalance } from './asserts'

describe('BetChip', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const testTokens = await deployTestTokens()
    await claimTestTokens(user, testTokens)

    const { USDC } = testTokens
    const BetChipManager = await deployBetChipManager()
    const BetChip = await createBetChip(owner, BetChipManager, USDC.address)

    return {
      ...testTokens,
      BetChip,
      publicClient,
      owner,
      user,
      hacker,
    }
  }

  describe('Swap', () => {
    it('#deposit()', async () => {
      const {
        USDC,
        BetChip,
        user,
      } = await loadFixture(deployFixture)
      const amount = parseUnits('10000', await USDC.read.decimals())

      await assert.isRejected(
        BetChip.write.deposit([0n], { account: user.account }),
        'InvalidAmount',
      )
      await assert.isRejected(
        BetChip.write.deposit([amount], { account: user.account }),
        'Underpayment',
      )

      await checkBalance(
        async () => {
          await USDC.write.approve([BetChip.address, amount], { account: user.account })
          await BetChip.write.deposit([amount], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, amount],
          [user.account.address, USDC.address, -amount],
        ],
      )
    })

    it('#withdraw()', async () => {
      const {
        USDC,
        BetChip,
        user,
      } = await loadFixture(deployFixture)
      const amount = parseUnits('10000', await USDC.read.decimals())
      await buyChip(user, BetChip, USDC.address, amount)

      await assert.isRejected(
        BetChip.write.withdraw([0n], { account: user.account }),
        'InvalidAmount',
      )
      await assert.isRejected(
        BetChip.write.withdraw([amount + 1n], { account: user.account }),
        'ERC20InsufficientBalance',
      )

      await checkBalance(
        async () => {
          await BetChip.write.withdraw([amount], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, -amount],
          [user.account.address, USDC.address, amount],
        ],
      )
    })
  })

  describe('Transfer', () => {
    it('#transfer()', async () => {
      const {
        USDC,
        BetChip,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const amount = parseUnits('10000', await USDC.read.decimals())
      await buyChip(user, BetChip, USDC.address, amount)

      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, hacker.account.address, amount)
        },
        [
          [user.account.address, BetChip.address, -amount],
          [hacker.account.address, BetChip.address, amount],
        ],
      )
    })

    it('#transfer() is able to wager', async () => {
      const {
        USDC,
        BetChip,
        user,
      } = await loadFixture(deployFixture)
      const amount = parseUnits('10000', await USDC.read.decimals())
      await buyChip(user, BetChip, USDC.address, amount)

      const TestBet = await viem.deployContract('TestBet', [
        0,
        BetChip.address,
        zeroAddress,
      ])

      const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
      await assert.isRejected(
        erc20Transfer(user, BetChip.address, TestBetOption.address, amount + 1n),
        'ChipInsufficientBalance',
      )

      assert.equal(await TestBetOption.read.wagered(), false)
      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, TestBetOption.address, amount)
        },
        [
          [user.account.address, BetChip.address, -amount],
        ],
      )
      assert.equal(await TestBetOption.read.wagered(), true)
    })

    it('#transfer() is able to dispute', async () => {
      const {
        USDC,
        BetChip,
        user,
      } = await loadFixture(deployFixture)
      const amount = parseUnits('10000', await USDC.read.decimals())
      await buyChip(user, BetChip, USDC.address, amount)

      const TestBet = await viem.deployContract('TestBet', [
        0,
        BetChip.address,
        zeroAddress,
      ])

      await assert.isRejected(
        erc20Transfer(user, BetChip.address, TestBet.address, amount + 1n),
        'ChipInsufficientBalance',
      )

      assert.equal(await TestBet.read.disputed(), false)
      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, TestBet.address, amount)
        },
        [
          [user.account.address, BetChip.address, -amount],
        ],
      )
      assert.equal(await TestBet.read.disputed(), true)
    })

    it('#transfer() is able to burn', async () => {
      const {
        USDC,
        BetChip,
        user,
      } = await loadFixture(deployFixture)
      const amount = parseUnits('10000', await USDC.read.decimals())
      await buyChip(user, BetChip, USDC.address, amount)

      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, BetChip.address, amount)
        },
        [
          [user.account.address, BetChip.address, -amount],
          [user.account.address, USDC.address, amount],
        ],
      )
    })
  })
})
