import { viem } from 'hardhat'
import { parseUnits } from 'viem'
import { exec } from '../utils'

exec(async () => {
  const USDC = await viem.deployContract('USDC')
  await USDC.write.mint([parseUnits('10000000000', 6)])
  console.log(`USDC deployed to: ${USDC.address}`)
})
