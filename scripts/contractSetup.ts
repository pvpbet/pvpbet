import { viem } from 'hardhat'
import { exec, readJson } from '../utils'

const network = process.env.HARDHAT_NETWORK as string

exec(async () => {
  const networks = await readJson('./networks.json')
  const chainId = networks[network].id
  const contracts = await readJson(`./ignition/deployments/chain-${chainId}/deployed_addresses.json`)
  const parameters = await readJson(`./ignition/parameters/chain-${chainId}.json`)

  const BetConfigurator = await viem.getContractAt('BetConfigurator', contracts['BetConfigurator#BetConfigurator'])
  const BetManager = await viem.getContractAt('BetManager', contracts['BetManager#BetManager'])
  const VotingEscrow = await viem.getContractAt('VotingEscrow', contracts['VotingEscrow#VotingEscrow'])

  await BetConfigurator.write.setOriginAllowlist([parameters.ContractSetup.originAllowlist])
  await BetManager.write.setCreationFee([parameters.ContractSetup.creationFee])
  await VotingEscrow.write.setGovTokenStaking([contracts['GovTokenStaking#GovTokenStaking']])

  console.log('The contract setup has been completed.')
})
