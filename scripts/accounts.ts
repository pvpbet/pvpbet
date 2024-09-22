import { viem } from 'hardhat'
import { parseUnits } from 'viem'
import { exec, readJson } from '../utils'
import type { Address } from 'viem'

exec(async () => {
  const contracts = (await readJson('./contracts.json')) as Record<string, Address>
  const USDC = await viem.getContractAt('USDC', contracts.USDC)
  const BetChip = await viem.getContractAt('BetChip', contracts.BetChip)
  const GovToken = await viem.getContractAt('GovToken', contracts.GovToken)
  const GovTokenStaking = await viem.getContractAt('GovTokenStaking', contracts.GovTokenStaking)

  const wallets = await viem.getWalletClients()

  const balance = parseUnits('100000000', 6)
  await USDC.write.mint([balance])
  await USDC.write.approve([BetChip.address, balance])
  await BetChip.write.deposit([balance])

  const chipAmount = parseUnits('10000000', 6)
  const govTokenAmount = parseUnits('10000000', 18)
  const count = 5
  for (let i = 1; i < count; i++) {
    const wallet = wallets[i]
    await BetChip.write.transfer([wallet.account.address, chipAmount])
    await GovToken.write.transfer([wallet.account.address, govTokenAmount])
    await GovToken.write.approve([GovTokenStaking.address, govTokenAmount], { account: wallet.account })
    await GovTokenStaking.write.stake([1, govTokenAmount / 10n * BigInt(count - i)], { account: wallet.account })
    await GovTokenStaking.write.stake([2, govTokenAmount / 10n * BigInt(count - i)], { account: wallet.account })
  }

  console.log('The accounts initialization has been completed.')
})
