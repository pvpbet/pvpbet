import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  getAddress,
  parseUnits,
} from 'viem'
import { deployGovToken } from './common'
import { checkBalance } from './asserts'

describe('GovToken', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const GovToken = await deployGovToken()

    return {
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
        GovToken,
        owner,
      } = await loadFixture(deployFixture)
      assert.equal(
        await GovToken.read.owner(),
        getAddress(owner.account.address),
      )
    })

    it('#transferOwnership()', async () => {
      const {
        GovToken,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        GovToken.write.transferOwnership([hacker.account.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await GovToken.write.transferOwnership([hacker.account.address], { account: owner.account })
      assert.equal(
        await GovToken.read.owner(),
        getAddress(hacker.account.address),
      )
    })
  })

  describe('Pausable', () => {
    it('#pause() #unpause()', async () => {
      const {
        GovToken,
        owner,
        hacker,
      } = await loadFixture(deployFixture)

      await assert.isRejected(
        GovToken.write.pause({ account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await GovToken.write.pause({ account: owner.account })

      const amount = parseUnits('1000', 18)
      await assert.isRejected(
        GovToken.write.transfer([hacker.account.address, amount], { account: owner.account }),
        'EnforcedPause',
      )

      await GovToken.write.unpause({ account: owner.account })

      await checkBalance(
        async () => {
          await GovToken.write.transfer([hacker.account.address, amount], { account: owner.account })
        },
        [
          [owner.account.address, GovToken.address, -amount],
          [hacker.account.address, GovToken.address, amount],
        ],
      )
    })
  })
})
