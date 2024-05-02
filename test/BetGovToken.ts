import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  getAddress,
  parseUnits,
} from 'viem'
import { deployBetGovToken } from './common'
import { checkBalance } from './asserts'

describe('BetGovToken', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const BetGovToken = await deployBetGovToken()

    return {
      BetGovToken,
      publicClient,
      owner,
      user,
      hacker,
    }
  }

  describe('Ownable', () => {
    it('#owner()', async () => {
      const {
        BetGovToken,
        owner,
      } = await loadFixture(deployFixture)
      assert.equal(
        await BetGovToken.read.owner(),
        getAddress(owner.account.address),
      )
    })

    it('#transferOwnership()', async () => {
      const {
        BetGovToken,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetGovToken.write.transferOwnership([hacker.account.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetGovToken.write.transferOwnership([hacker.account.address], { account: owner.account })
      assert.equal(
        await BetGovToken.read.owner(),
        getAddress(hacker.account.address),
      )
    })
  })

  describe('Pausable', () => {
    it('#pause() #unpause()', async () => {
      const {
        BetGovToken,
        owner,
        hacker,
      } = await loadFixture(deployFixture)

      await assert.isRejected(
        BetGovToken.write.pause({ account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetGovToken.write.pause({ account: owner.account })

      const amount = parseUnits('1000', 18)
      await assert.isRejected(
        BetGovToken.write.transfer([hacker.account.address, amount], { account: owner.account }),
        'EnforcedPause',
      )

      await BetGovToken.write.unpause({ account: owner.account })

      await checkBalance(
        async () => {
          await BetGovToken.write.transfer([hacker.account.address, amount], { account: owner.account })
        },
        [
          [owner.account.address, BetGovToken.address, -amount],
          [hacker.account.address, BetGovToken.address, amount],
        ],
      )
    })
  })
})
