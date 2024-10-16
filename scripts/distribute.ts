import { viem } from 'hardhat'
import { parseEther, parseUnits } from 'viem'
import { exec, readJson } from '../utils'

exec(async chainId => {
  const contracts = await readJson(`./ignition/deployments/chain-${chainId}/deployed_addresses.json`)
  const parameters = await readJson(`./ignition/parameters/chain-${chainId}.json`)

  const GovTokenStaking = await viem.getContractAt('GovTokenStaking', contracts['GovTokenStaking#GovTokenStaking'])
  const USDC = await viem.getContractAt('USDC', parameters.BetChip.token)
  const BetChip = await viem.getContractAt('BetChip', parameters.BetChip.chip)

  const ethAmount = parseEther('10')
  await GovTokenStaking.write.distribute({ value: ethAmount })

  const decimals = await BetChip.read.decimals()
  const chipAmount = parseUnits('10000', decimals)
  await USDC.write.approve([BetChip.address, chipAmount])
  await BetChip.write.deposit([chipAmount])
  await BetChip.write.approve([GovTokenStaking.address, chipAmount])
  await GovTokenStaking.write.distribute([BetChip.address, chipAmount])
  console.log('The rewards distribution has been completed.')
})
