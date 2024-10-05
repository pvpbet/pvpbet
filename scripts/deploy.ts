import { ignition } from 'hardhat'
import { parseUnits, zeroAddress } from 'viem'
import { exec, readJson, writeJson } from '../utils'
import BetChipModule from '../ignition/modules/BetChip'
import BetVotingEscrowModule from '../ignition/modules/BetVotingEscrow'
import BetManagerModule from '../ignition/modules/BetManager'
import ContractSetupModule from '../ignition/modules/ContractSetup'
import GovTokenModule from '../ignition/modules/GovToken'
import GovTokenStakingModule from '../ignition/modules/GovTokenStaking'
import TestUSDCModule from '../ignition/modules/TestUSDC'
import parameters from '../ignition/parameters_sepolia.json'
import type { Address } from 'viem'

const network = process.env.HARDHAT_NETWORK as string

exec(async () => {
  const contracts = (await readJson('./contracts.json')) as Record<string, Record<string, Address>>
  contracts[network] = {}

  const { USDC } = await ignition.deploy(TestUSDCModule)
  await USDC.write.mint([parseUnits('10000000000', 6)])
  contracts[network].USDC = USDC.address
  console.log(`USDC deployed to: ${USDC.address}`)

  const { BetChip } = await ignition.deploy(BetChipModule, {
    parameters: {
      BetChip: {
        currency: USDC.address,
      },
    },
  })
  contracts[network].BetChip = BetChip.address
  console.log(`BetChip deployed to: ${BetChip.address}`)

  const { BetVotingEscrow } = await ignition.deploy(BetVotingEscrowModule)
  contracts[network].BetVotingEscrow = BetVotingEscrow.address
  console.log(`BetVotingEscrow deployed to: ${BetVotingEscrow.address}`)

  const { GovToken } = await ignition.deploy(GovTokenModule)
  contracts[network].GovToken = GovToken.address
  console.log(`GovToken deployed to: ${GovToken.address}`)

  const { GovTokenStaking } = await ignition.deploy(GovTokenStakingModule, {
    parameters: {
      GovTokenStaking: {
        govToken: GovToken.address,
        voteToken: BetVotingEscrow.address,
        rewardTokens: [
          zeroAddress,
          BetChip.address,
        ],
      },
    },
  })
  contracts[network].GovTokenStaking = GovTokenStaking.address
  console.log(`GovTokenStaking deployed to: ${GovTokenStaking.address}`)

  const { BetManager, BetConfigurator } = await ignition.deploy(BetManagerModule, {
    parameters: {
      BetManager: {
        govToken: GovToken.address,
        chipToken: BetChip.address,
        voteToken: BetVotingEscrow.address,
      },
    },
  })
  contracts[network].BetManager = BetManager.address
  console.log(`BetManager deployed to: ${BetManager.address}`)
  contracts[network].BetConfigurator = BetConfigurator.address
  console.log(`BetConfigurator deployed to: ${BetConfigurator.address}`)

  await ignition.deploy(ContractSetupModule, {
    parameters: {
      ContractSetup: {
        BetConfigurator: BetConfigurator.address,
        BetManager: BetManager.address,
        BetVotingEscrow: BetVotingEscrow.address,
        GovTokenStaking: GovTokenStaking.address,
        creationFee: parameters.ContractSetup.creationFee,
        originAllowlist: parameters.ContractSetup.originAllowlist,
      },
    },
  })
  console.log('The contract setup has been completed.')

  await writeJson('./contracts.json', contracts)
})
