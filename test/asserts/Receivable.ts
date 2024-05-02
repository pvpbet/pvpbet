import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  parseEther,
  parseUnits,
} from 'viem'
import {
  deployTestTokens,
  claimTestTokens,
  depositAssets,
} from '../common'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export type ReceivableTestOptions = {
  extra?: () => void
}

export function testReceivable(
  baseDeployFixture: () => Promise<{
    Receivable: ContractTypes['Receivable']
    owner: WalletClient
  }>,
  options?: ReceivableTestOptions,
) {
  async function deployFixture() {
    const { Receivable, owner } = await baseDeployFixture()
    const publicClient = await viem.getPublicClient()

    const testTokens = await deployTestTokens()
    await claimTestTokens(owner, testTokens)
    await depositAssets(owner, Receivable.address, testTokens)

    return {
      ...testTokens,
      Receivable,
      publicClient,
    }
  }

  describe('Receivable', () => {
    it('#receive()', async () => {
      const {
        DAI,
        USDC,
        Receivable,
        publicClient,
      } = await loadFixture(deployFixture)
      assert.equal(
        await publicClient.getBalance({ address: Receivable.address }),
        parseEther('100'),
      )
      assert.equal(
        await DAI.read.balanceOf([Receivable.address]),
        parseUnits('1000000', 18),
      )
      assert.equal(
        await USDC.read.balanceOf([Receivable.address]),
        parseUnits('1000000', 6),
      )
    })

    options?.extra?.()
  })
}
