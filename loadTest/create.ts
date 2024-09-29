import { viem } from 'hardhat'
import { parseUnits } from 'viem'
import { exec, readJson } from '../utils'
import { BetDetails } from '../test/common/bet'
import type { Address } from 'viem'

const DAY = 24n * 3600n
const count = 10

exec(async () => {
  const contracts = (await readJson('./contracts.json')) as Record<string, Address>
  const GovToken = await viem.getContractAt('GovToken', contracts.GovToken)
  const BetManager = await viem.getContractAt('BetManager', contracts.BetManager)

  for (let i = 0; i < count; i++) {
    await GovToken.write.approve([BetManager.address, parseUnits('100', 18)])
    await BetManager.write.createBet(
      [
        Object.assign({}, BetDetails, { title: `[${i + 1}] ${BetDetails.title}` }),
        DAY * 3n,
        DAY * 3n,
      ],
    )
    console.log(`${i + 1} have been created.`)
  }

  console.log('The test has been completed.')
})
