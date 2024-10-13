import { viem } from 'hardhat'
import { parseUnits, zeroAddress } from 'viem'
import { exec, readJson } from '../utils'
import { BetDetails } from '../test/common/bet'

const network = process.env.HARDHAT_NETWORK as string
const DAY = 24n * 3600n
const count = 5

exec(async () => {
  const networks = await readJson('./networks.json')
  const chainId = networks[network].id
  const contracts = await readJson(`./ignition/deployments/chain-${chainId}/deployed_addresses.json`)
  const parameters = await readJson(`./ignition/parameters/chain-${chainId}.json`)

  const GovToken = await viem.getContractAt('GovToken', contracts['GovToken#GovToken'])
  const BetManager = await viem.getContractAt('BetManager', contracts['BetManager#BetManager'])
  const chip = parameters.BetChip.chip

  for (let i = 0; i < count; i++) {
    await GovToken.write.approve([BetManager.address, parseUnits('100', 18)])
    await BetManager.write.createBet(
      [
        Object.assign({}, BetDetails, { title: `[${i + 1}] ${BetDetails.title}` }),
        DAY * 2n + BigInt(i) * (DAY * 88n / BigInt(count - 1)),
        DAY * 2n,
        i % 2 ? chip : zeroAddress,
      ],
    )
    console.log(`${i + 1} have been created.`)
  }

  console.log('The test has been completed.')
})
