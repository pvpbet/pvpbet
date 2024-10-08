import { viem } from 'hardhat'
import { exec, readJson } from '../utils'
import { createBetChip } from '../test/common/chip'

const network = process.env.HARDHAT_NETWORK as string

exec(async () => {
  const networks = await readJson('./networks.json')
  const chainId = networks[network].id
  const contracts = await readJson(`./ignition/deployments/chain-${chainId}/deployed_addresses.json`)
  const parameters = await readJson(`./ignition/parameters/chain-${chainId}.json`)

  const [owner] = await viem.getWalletClients()

  const BetChipManager = await viem.getContractAt('BetChipManager', contracts['BetChipManager#BetChipManager'])
  const BetChip = await createBetChip(owner, BetChipManager, parameters.BetChip.token)
  console.log(`BetChip deployed to: ${BetChip.address}`)
})
