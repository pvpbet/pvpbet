import { viem } from 'hardhat'
import { parseEther, parseUnits } from 'viem'
import { exec, readJson } from '../utils'
import type { Address } from 'viem'

exec(async () => {
  const contracts = (await readJson('./contracts.json')) as Record<string, Address>
  const USDC = await viem.getContractAt('USDC', contracts.USDC)
  const BetChip = await viem.getContractAt('BetChip', contracts.BetChip)
  const GovTokenStaking = await viem.getContractAt('GovTokenStaking', contracts.GovTokenStaking)

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
