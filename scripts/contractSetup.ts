import { viem } from 'hardhat'
import { exec, readJson } from '../utils'

exec(async chainId => {
  const contracts = await readJson(`./ignition/deployments/chain-${chainId}/deployed_addresses.json`)
  const parameters = await readJson(`./ignition/parameters/chain-${chainId}.json`)

  const BetConfigurator = await viem.getContractAt('BetConfigurator', contracts['BetConfigurator#BetConfigurator'])
  const BetManager = await viem.getContractAt('BetManager', contracts['BetManager#BetManager'])

  const publicClient = await viem.getPublicClient()

  let hash
  hash = await BetConfigurator.write.setOriginAllowlist([parameters.ContractSetup.originAllowlist])
  await publicClient.waitForTransactionReceipt({ hash })
  hash = await BetManager.write.setCreationFee([parameters.ContractSetup.creationFee])
  await publicClient.waitForTransactionReceipt({ hash })

  console.log('The contract setup has been completed.')
})
