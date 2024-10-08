import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  getAddress,
  zeroAddress,
} from 'viem'
import { deployTestTokens } from './common'
import {
  createBetChip,
  deployBetChipManager,
} from './common/chip'

describe('BetChipManager', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const testTokens = await deployTestTokens()
    const BetChipManager = await deployBetChipManager()

    return {
      ...testTokens,
      BetChipManager,
      publicClient,
      owner,
      user,
      hacker,
    }
  }

  describe('Ownable', () => {
    it('#owner()', async () => {
      const {
        BetChipManager,
        owner,
      } = await loadFixture(deployFixture)
      assert.equal(
        await BetChipManager.read.owner(),
        getAddress(owner.account.address),
      )
    })

    it('#transferOwnership()', async () => {
      const {
        BetChipManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetChipManager.write.transferOwnership([hacker.account.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetChipManager.write.transferOwnership([hacker.account.address], { account: owner.account })
      assert.equal(
        await BetChipManager.read.owner(),
        getAddress(hacker.account.address),
      )
    })
  })

  describe('Configure the contracts', () => {
    it('#betChipFactory() #setBetChipFactory()', async () => {
      const {
        BetChipManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetChipManager.write.setBetChipFactory([zeroAddress], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetChipManager.write.setBetChipFactory([zeroAddress], { account: owner.account })
      assert.equal(
        await BetChipManager.read.betChipFactory(),
        zeroAddress,
      )
    })
  })

  describe('Bet chips management', () => {
    it('Create a bet chip', async () => {
      const {
        DAI,
        USDC,
        BetChipManager,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        createBetChip(hacker, BetChipManager, USDC.address),
        'OwnableUnauthorizedAccount',
      )
      await assert.isRejected(
        createBetChip(owner, BetChipManager, zeroAddress),
        'InvalidERC20Token',
      )
      await assert.isRejected(
        createBetChip(owner, BetChipManager, BetChipManager.address),
        'InvalidERC20Token',
      )

      const tokens = [DAI, USDC]
      for (const token of tokens) {
        const BetChip = await createBetChip(owner, BetChipManager, token.address)
        assert.equal(await BetChipManager.read.isBetChip([BetChip.address]), true)
        assert.equal(await BetChipManager.read.isBetChip([token.address]), false)
        assert.equal(await BetChip.read.name(), `PVPBetChipWrapped${await token.read.name()}`)
        assert.equal(await BetChip.read.symbol(), `cw${await token.read.symbol()}`)
      }
    })
  })
})
