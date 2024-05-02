import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  parseEther,
  parseUnits,
  zeroAddress,
} from 'viem'
import {
  deployTestTokens,
  claimTestTokens,
  depositAssets,
} from '../common'
import { checkBalance } from './index'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export type WithdrawableTestOptions = {
  extra?: () => void
}

export function testWithdrawable(
  baseDeployFixture: () => Promise<{
    Withdrawable: ContractTypes['Withdrawable']
    owner: WalletClient
  }>,
  options?: WithdrawableTestOptions,
) {
  async function deployFixture() {
    const { Withdrawable, owner } = await baseDeployFixture()
    const publicClient = await viem.getPublicClient()
    const walletClients = await viem.getWalletClients()
    const ownerIndex = walletClients.findIndex(
      client => client.account.address === owner.account.address,
    )

    const testTokens = await deployTestTokens()
    await claimTestTokens(owner, testTokens)
    await depositAssets(owner, Withdrawable.address, testTokens)

    return {
      ...testTokens,
      Withdrawable,
      publicClient,
      user: owner,
      hacker: walletClients[ownerIndex + 1],
    }
  }

  describe('Withdrawable', () => {
    it('#withdraw()', async () => {
      const {
        Withdrawable,
        publicClient,
        user,
        hacker,
      } = await loadFixture(deployFixture)

      await assert.isRejected(
        Withdrawable.write.withdraw({ account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      const totalAmount = await publicClient.getBalance({ address: Withdrawable.address })
      const amount = parseEther('3')

      await checkBalance(
        async () => {
          await Withdrawable.write.withdraw([amount], { account: user.account })
        },
        [
          [user.account.address, zeroAddress, amount],
          [Withdrawable.address, zeroAddress, -amount],
        ],
      )

      await checkBalance(
        async () => {
          await Withdrawable.write.withdraw({ account: user.account })
        },
        [
          [user.account.address, zeroAddress, totalAmount - amount],
          [Withdrawable.address, zeroAddress, -(totalAmount - amount)],
        ],
      )

      assert.equal(
        await publicClient.getBalance({ address: Withdrawable.address }),
        0n,
      )
    })

    it('#withdrawERC20()', async () => {
      const {
        USDC,
        Withdrawable,
        hacker,
        user,
      } = await loadFixture(deployFixture)

      await assert.isRejected(
        Withdrawable.write.withdrawERC20([USDC.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      const totalAmount = await USDC.read.balanceOf([Withdrawable.address])
      const amount = parseUnits('3000', 6)

      await checkBalance(
        async () => {
          await Withdrawable.write.withdrawERC20([USDC.address, amount], { account: user.account })
        },
        [
          [user.account.address, USDC.address, amount],
          [Withdrawable.address, USDC.address, -amount],
        ],
      )

      await checkBalance(
        async () => {
          await Withdrawable.write.withdrawERC20([USDC.address], { account: user.account })
        },
        [
          [user.account.address, USDC.address, totalAmount - amount],
          [Withdrawable.address, USDC.address, -(totalAmount - amount)],
        ],
      )

      assert.equal(
        await USDC.read.balanceOf([Withdrawable.address]),
        0n,
      )
    })

    options?.extra?.()
  })
}
