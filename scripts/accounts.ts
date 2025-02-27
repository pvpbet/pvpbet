import { viem } from 'hardhat'
import { parseUnits } from 'viem'
import { exec, readJson } from '../utils'

exec(async chainId => {
  const contracts = await readJson(`./ignition/deployments/chain-${chainId}/deployed_addresses.json`)
  const parameters = await readJson(`./ignition/parameters/chain-${chainId}.json`)

  const GovToken = await viem.getContractAt('GovToken', contracts['GovToken#GovToken'])
  const GovTokenStaking = await viem.getContractAt('GovTokenStaking', contracts['GovTokenStaking#GovTokenStaking'])
  const USDC = await viem.getContractAt('USDC', parameters.BetChip.token)
  const BetChip = await viem.getContractAt('BetChip', parameters.BetChip.chip)

  const wallets = await viem.getWalletClients()

  const balance = parseUnits('100000000', 6)
  await USDC.write.mint([balance])
  await USDC.write.approve([BetChip.address, balance])
  await BetChip.write.deposit([balance])

  const chipAmount = parseUnits('10000000', 6)
  const govTokenAmount = parseUnits('10000000', 18)
  const count = 5
  for (let i = 0; i < count; i++) {
    const wallet = wallets[i]
    await BetChip.write.transfer([wallet.account.address, chipAmount])
    await GovToken.write.transfer([wallet.account.address, govTokenAmount])
    await GovToken.write.approve([GovTokenStaking.address, govTokenAmount], { account: wallet.account })
    await GovTokenStaking.write.stake([1, govTokenAmount / 10n * BigInt(count - i)], { account: wallet.account })
    await GovTokenStaking.write.stake([2, govTokenAmount / 10n * BigInt(count - i)], { account: wallet.account })
    console.log(`[${i + 1}] The account has been initialized.`)
  }

  console.log('The accounts initialization has been completed.')
})
