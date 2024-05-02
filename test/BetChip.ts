import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { assert } from 'chai'
import { viem } from 'hardhat'
import {
  getAddress,
  parseUnits,
  zeroAddress,
} from 'viem'
import {
  erc20Approve,
  erc20Transfer,
} from '../utils'
import {
  claimTestTokens,
  deployTestTokens,
} from './common'
import { buyChip, deployBetChip } from './common/chip'
import { checkBalance } from './asserts'
import { testReceivable } from './asserts/Receivable'
import { testWithdrawable } from './asserts/Withdrawable'
import type { ContractTypes } from '../types'

describe('BetChip', () => {
  async function deployFixture() {
    const publicClient = await viem.getPublicClient()
    const [owner, user, hacker] = await viem.getWalletClients()

    const testTokens = await deployTestTokens()
    await claimTestTokens(user, testTokens)

    const { DAI, USDC } = testTokens
    const currencies = [
      getAddress(DAI.address),
      getAddress(USDC.address),
    ]
    const rates = [
      1n,
      10n ** 12n,
    ]
    const BetChip = await deployBetChip(currencies, rates)

    return {
      ...testTokens,
      BetChip,
      publicClient,
      owner,
      user,
      hacker,
      currencies,
      rates,
    }
  }

  describe('Ownable', () => {
    it('#owner()', async () => {
      const {
        BetChip,
        owner,
      } = await loadFixture(deployFixture)
      assert.equal(
        await BetChip.read.owner(),
        getAddress(owner.account.address),
      )
    })

    it('#transferOwnership()', async () => {
      const {
        BetChip,
        owner,
        hacker,
      } = await loadFixture(deployFixture)
      await assert.isRejected(
        BetChip.write.transferOwnership([hacker.account.address], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetChip.write.transferOwnership([hacker.account.address], { account: owner.account })
      assert.equal(
        await BetChip.read.owner(),
        getAddress(hacker.account.address),
      )
    })
  })

  describe('Config', () => {
    it('#currenciesAndRates()', async () => {
      const {
        BetChip,
        currencies,
        rates,
      } = await loadFixture(deployFixture)
      assert.deepEqual(await BetChip.read.currenciesAndRates(), [
        currencies,
        rates,
      ])
    })

    it('#setCurrenciesAndRates()', async () => {
      const {
        BetChip,
        owner,
        hacker,
        currencies,
        rates,
      } = await loadFixture(deployFixture)
      const newCurrencies = currencies.slice(0, 1)
      const newRates = rates.slice(0, 1)
      await assert.isRejected(
        BetChip.write.setCurrenciesAndRates([newCurrencies, newRates], { account: hacker.account }),
        'OwnableUnauthorizedAccount',
      )

      await BetChip.write.setCurrenciesAndRates([newCurrencies, newRates], { account: owner.account })
      assert.deepEqual(await BetChip.read.currenciesAndRates(), [
        newCurrencies,
        newRates,
      ])
    })
  })

  describe('Swap', () => {
    it('#getTokenAmount()', async () => {
      const {
        BetChip,
        currencies,
        rates,
      } = await loadFixture(deployFixture)
      const currencyDAI = currencies[0]
      const currencyUSDC = currencies[1]
      const amountDAI = parseUnits('10000', 18)
      const amountUSDC = parseUnits('10000', 6)
      const quantityDAI = rates[0] * amountDAI
      const quantityUSDC = rates[1] * amountUSDC
      assert.equal(
        await BetChip.read.getTokenAmount([currencyDAI, quantityDAI]),
        amountDAI,
      )
      assert.equal(
        await BetChip.read.getTokenAmount([currencyUSDC, quantityUSDC]),
        amountUSDC,
      )
    })

    it('#getTokenQuantity()', async () => {
      const {
        BetChip,
        currencies,
        rates,
      } = await loadFixture(deployFixture)
      const currencyDAI = currencies[0]
      const currencyUSDC = currencies[1]
      const amountDAI = parseUnits('10000', 18)
      const amountUSDC = parseUnits('10000', 6)
      const quantityDAI = rates[0] * amountDAI
      const quantityUSDC = rates[1] * amountUSDC
      assert.equal(
        await BetChip.read.getTokenQuantity([currencyDAI, amountDAI]),
        quantityDAI,
      )
      assert.equal(
        await BetChip.read.getTokenQuantity([currencyUSDC, amountUSDC]),
        quantityUSDC,
      )
    })

    it('#buy()', async () => {
      const {
        DAI,
        USDC,
        BetChip,
        user,
        currencies,
        rates,
      } = await loadFixture(deployFixture)

      const currencyDAI = currencies[0]
      const currencyUSDC = currencies[1]
      const amountDAI = parseUnits('8000', 18)
      const amountUSDC = parseUnits('9000', 6)
      const quantityDAI = rates[0] * amountDAI
      const quantityUSDC = rates[1] * amountUSDC

      await assert.isRejected(
        BetChip.write.buy([currencyDAI, 0n], { account: user.account }),
        'QuantityMustBeGreaterThanZero',
      )
      await assert.isRejected(
        BetChip.write.buy([currencyUSDC, quantityUSDC], { account: user.account }),
        'Underpayment',
      )

      await checkBalance(
        async () => {
          await erc20Approve(user, DAI.address, BetChip.address, amountDAI)
          await BetChip.write.buy([DAI.address, quantityDAI], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, quantityDAI],
          [user.account.address, DAI.address, -amountDAI],
        ],
      )

      await checkBalance(
        async () => {
          await erc20Approve(user, USDC.address, BetChip.address, amountUSDC)
          await BetChip.write.buy([USDC.address, quantityUSDC], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, quantityUSDC],
          [user.account.address, USDC.address, -amountUSDC],
        ],
      )
    })

    it('#sell()', async () => {
      const {
        DAI,
        USDC,
        BetChip,
        user,
        currencies,
        rates,
      } = await loadFixture(deployFixture)

      const currencyDAI = currencies[0]
      const currencyUSDC = currencies[1]
      const amountDAI = parseUnits('8000', 18)
      const amountUSDC = parseUnits('9000', 6)
      const quantityDAI = rates[0] * amountDAI
      const quantityUSDC = rates[1] * amountUSDC

      await buyChip(user, BetChip, currencyDAI, quantityDAI)
      await buyChip(user, BetChip, currencyUSDC, quantityUSDC)

      await assert.isRejected(
        BetChip.write.sell([currencyDAI, 0n], { account: user.account }),
        'QuantityMustBeGreaterThanZero',
      )
      await assert.isRejected(
        BetChip.write.sell([currencyDAI, quantityDAI + quantityUSDC], { account: user.account }),
        'ERC20InsufficientBalance',
      )

      await checkBalance(
        async () => {
          await BetChip.write.sell([currencyDAI, quantityDAI], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, -quantityDAI],
          [user.account.address, DAI.address, amountDAI],
        ],
      )

      await checkBalance(
        async () => {
          await BetChip.write.sell([currencyUSDC, quantityUSDC], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, -quantityUSDC],
          [user.account.address, USDC.address, amountUSDC],
        ],
      )
    })

    it('#deposit()', async () => {
      const {
        DAI,
        USDC,
        BetChip,
        user,
        currencies,
        rates,
      } = await loadFixture(deployFixture)

      const currencyDAI = currencies[0]
      const currencyUSDC = currencies[1]
      const amountDAI = parseUnits('8000', 18)
      const amountUSDC = parseUnits('9000', 6)
      const quantityDAI = rates[0] * amountDAI
      const quantityUSDC = rates[1] * amountUSDC

      await assert.isRejected(
        BetChip.write.deposit([currencyDAI, 0n], { account: user.account }),
        'AmountMustBeGreaterThanZero',
      )
      await assert.isRejected(
        BetChip.write.deposit([currencyUSDC, amountUSDC], { account: user.account }),
        'Underpayment',
      )

      await checkBalance(
        async () => {
          await erc20Approve(user, DAI.address, BetChip.address, amountDAI)
          await BetChip.write.deposit([DAI.address, amountDAI], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, quantityDAI],
          [user.account.address, DAI.address, -amountDAI],
        ],
      )

      await checkBalance(
        async () => {
          await erc20Approve(user, USDC.address, BetChip.address, amountUSDC)
          await BetChip.write.deposit([USDC.address, amountUSDC], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, quantityUSDC],
          [user.account.address, USDC.address, -amountUSDC],
        ],
      )
    })

    it('#withdraw()', async () => {
      const {
        DAI,
        USDC,
        BetChip,
        user,
        currencies,
        rates,
      } = await loadFixture(deployFixture)

      const currencyDAI = currencies[0]
      const currencyUSDC = currencies[1]
      const amountDAI = parseUnits('8000', 18)
      const amountUSDC = parseUnits('9000', 6)
      const quantityDAI = rates[0] * amountDAI
      const quantityUSDC = rates[1] * amountUSDC

      await buyChip(user, BetChip, currencyDAI, quantityDAI)
      await buyChip(user, BetChip, currencyUSDC, quantityUSDC)

      await assert.isRejected(
        BetChip.write.withdraw([currencyDAI, 0n], { account: user.account }),
        'AmountMustBeGreaterThanZero',
      )
      await assert.isRejected(
        BetChip.write.withdraw([currencyDAI, amountDAI + amountUSDC], { account: user.account }),
        'ERC20InsufficientBalance',
      )

      await checkBalance(
        async () => {
          await BetChip.write.withdraw([currencyDAI, amountDAI], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, -quantityDAI],
          [user.account.address, DAI.address, amountDAI],
        ],
      )

      await checkBalance(
        async () => {
          await BetChip.write.withdraw([currencyUSDC, amountUSDC], { account: user.account })
        },
        [
          [user.account.address, BetChip.address, -quantityUSDC],
          [user.account.address, USDC.address, amountUSDC],
        ],
      )
    })
  })

  describe('Transfer', () => {
    it('#transfer()', async () => {
      const {
        DAI,
        BetChip,
        user,
        hacker,
      } = await loadFixture(deployFixture)
      const quantity = parseUnits('1000', 18)
      await buyChip(user, BetChip, DAI.address, quantity)

      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, hacker.account.address, quantity)
        },
        [
          [user.account.address, BetChip.address, -quantity],
          [hacker.account.address, BetChip.address, quantity],
        ],
      )
    })

    it('#transfer() is able to wager', async () => {
      const {
        DAI,
        BetChip,
        user,
      } = await loadFixture(deployFixture)
      const quantity = parseUnits('80000', 18)
      await buyChip(user, BetChip, DAI.address, quantity)

      const wageredAmount = parseUnits('10000', 18)
      const TestBet = await viem.deployContract('TestBet', [
        0,
        BetChip.address,
        zeroAddress,
      ])

      const TestBetOption = await viem.deployContract('TestBetOption', [TestBet.address])
      await assert.isRejected(
        erc20Transfer(user, BetChip.address, TestBetOption.address, quantity + 1n),
        'ChipInsufficientBalance',
      )

      assert.equal(await TestBetOption.read.wagered(), false)
      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, TestBetOption.address, wageredAmount)
        },
        [
          [user.account.address, BetChip.address, -wageredAmount],
        ],
      )
      assert.equal(await TestBetOption.read.wagered(), true)
    })

    it('#transfer() is able to dispute', async () => {
      const {
        DAI,
        BetChip,
        user,
      } = await loadFixture(deployFixture)
      const quantity = parseUnits('80000', 18)
      await buyChip(user, BetChip, DAI.address, quantity)

      const disputedAmount = parseUnits('10000', 18)
      const TestBet = await viem.deployContract('TestBet', [
        0,
        BetChip.address,
        zeroAddress,
      ])

      await assert.isRejected(
        erc20Transfer(user, BetChip.address, TestBet.address, quantity + 1n),
        'ChipInsufficientBalance',
      )

      assert.equal(await TestBet.read.disputed(), false)
      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, TestBet.address, disputedAmount)
        },
        [
          [user.account.address, BetChip.address, -disputedAmount],
        ],
      )
      assert.equal(await TestBet.read.disputed(), true)
    })

    it('#transfer() is able to burn', async () => {
      const {
        DAI,
        USDC,
        BetChip,
        user,
        currencies,
        rates,
      } = await loadFixture(deployFixture)

      const currencyDAI = currencies[0]
      const currencyUSDC = currencies[1]
      const amountDAI = parseUnits('8000', 18)
      const amountUSDC = parseUnits('9000', 6)
      const quantityDAI = rates[0] * amountDAI
      const quantityUSDC = rates[1] * amountUSDC

      await buyChip(user, BetChip, currencyDAI, quantityDAI)
      await buyChip(user, BetChip, currencyUSDC, quantityUSDC)
      const totalSupply = await BetChip.read.totalSupply()

      // Currently, USDC > DAI in the BetChip contract.
      const step1Quantity = quantityUSDC / 2n
      const step1Amount = await BetChip.read.getTokenAmount([currencyUSDC, step1Quantity])
      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, BetChip.address, step1Quantity)
        },
        [
          [BetChip.address, DAI.address, 0n],
          [BetChip.address, USDC.address, -step1Amount],
          [user.account.address, DAI.address, 0n],
          [user.account.address, USDC.address, step1Amount],
          [user.account.address, BetChip.address, -step1Quantity],
        ],
      )

      // Currently, DAI > USDC in the BetChip contract.
      const step2Quantity = quantityDAI / 2n
      const step2Amount = await BetChip.read.getTokenAmount([currencyDAI, step2Quantity])
      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, BetChip.address, step2Quantity)
        },
        [
          [BetChip.address, DAI.address, -step2Amount],
          [BetChip.address, USDC.address, 0n],
          [user.account.address, DAI.address, step2Amount],
          [user.account.address, USDC.address, 0n],
          [user.account.address, BetChip.address, -step2Quantity],
        ],
      )

      // Burn the remaining.
      await checkBalance(
        async () => {
          await erc20Transfer(user, BetChip.address, BetChip.address, step1Quantity + step2Quantity)
        },
        [
          [user.account.address, BetChip.address, -(step1Quantity + step2Quantity)],
          [user.account.address, DAI.address, step2Amount],
          [user.account.address, USDC.address, step1Amount],
        ],
      )

      assert.equal(
        await BetChip.read.totalSupply(),
        totalSupply - quantityDAI - quantityUSDC,
      )
    })
  })

  testReceivable(async () => {
    const { BetChip, owner } = await loadFixture(deployFixture)
    return {
      Receivable: BetChip as unknown as ContractTypes['Receivable'],
      owner,
    }
  })

  testWithdrawable(async () => {
    const { BetChip, owner } = await loadFixture(deployFixture)
    return {
      Withdrawable: BetChip as unknown as ContractTypes['Withdrawable'],
      owner,
    }
  })
})
