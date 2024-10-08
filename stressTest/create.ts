import { viem } from 'hardhat'
import { parseUnits } from 'viem'
import { exec, readJson } from '../utils'
import { BetDetails } from '../test/common/bet'
import type { Address } from 'viem'

const network = process.env.HARDHAT_NETWORK as string
const DAY = 24n * 3600n
const count = 5

exec(async () => {
  const networks = await readJson('./networks.json')
  const chainId = networks[network].id
  const contracts = await readJson(`./ignition/deployments/chain-${chainId}/deployed_addresses.json`)

  const GovToken = await viem.getContractAt('GovToken', contracts['GovToken#GovToken'])
  const BetManager = await viem.getContractAt('BetManager', contracts['BetManager#BetManager'])
  const chip = contracts['BetChip#BetChip']

  for (let i = 0; i < count; i++) {
    await GovToken.write.approve([BetManager.address, parseUnits('100', 18)])
    await BetManager.write.createBet(
      [
        Object.assign({}, BetDetails, { title: `[${i + 1}] ${BetDetails.title}` }),
        DAY * 2n + BigInt(i) * (DAY * 88n / BigInt(count - 1)),
        DAY * 2n,
        chip,
      ],
    )
    console.log(`${i + 1} have been created.`)
  }

  console.log('The test has been completed.')
})
