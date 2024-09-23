import { viem } from 'hardhat'
import { exec, readJson } from '../utils'
import type { Address } from 'viem'

exec(async () => {
  const contracts = (await readJson('./contracts.json')) as Record<string, Address>
  const BetManager = await viem.getContractAt('BetManager', contracts.BetManager)
  await BetManager.write.clear()
  console.log('The cleanup has been completed.')
})
