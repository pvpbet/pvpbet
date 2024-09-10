import { viem, ignition } from 'hardhat'
import { parseUnits } from 'viem'
import { exec, writeJson } from '../utils'
import GovTokenModule from '../ignition/modules/GovToken'
import GovTokenStakingModule from '../ignition/modules/GovTokenStaking'
import BetChipModule from '../ignition/modules/BetChip'
import BetVotingEscrowModule from '../ignition/modules/BetVotingEscrow'
import BetManagerModule from '../ignition/modules/BetManager'
import type { Address } from 'viem'

exec(async () => {
  const contracts: Record<string, Address> = {}

  const USDC = await viem.deployContract('USDC')
  await USDC.write.mint([parseUnits('10000000000', 6)])
  contracts.USDC = USDC.address
  console.log(`USDC deployed to: ${USDC.address}`)

  const currencies = [USDC.address]
  const rates = [10n ** 12n]

  const { BetChip } = await ignition.deploy(BetChipModule, {
    parameters: {
      BetChip: {
        currencies,
        rates,
      },
    },
  })
  contracts.BetChip = BetChip.address
  console.log(`BetChip deployed to: ${BetChip.address}`)

  const { BetVotingEscrow } = await ignition.deploy(BetVotingEscrowModule)
  contracts.BetVotingEscrow = BetVotingEscrow.address
  console.log(`BetVotingEscrow deployed to: ${BetVotingEscrow.address}`)

  const { GovToken } = await ignition.deploy(GovTokenModule)
  contracts.GovToken = GovToken.address
  console.log(`GovToken deployed to: ${GovToken.address}`)

  const { GovTokenStaking } = await ignition.deploy(GovTokenStakingModule, {
    parameters: {
      GovTokenStaking: {
        govToken: GovToken.address,
        voteToken: BetVotingEscrow.address,
      },
    },
  })
  contracts.GovTokenStaking = GovTokenStaking.address
  console.log(`GovTokenStaking deployed to: ${GovTokenStaking.address}`)

  const { BetManager } = await ignition.deploy(BetManagerModule, {
    parameters: {
      BetManager: {
        govToken: GovToken.address,
        chipToken: BetChip.address,
        voteToken: BetVotingEscrow.address,
      },
    },
  })
  contracts.BetManager = BetManager.address
  console.log(`BetManager deployed to: ${BetManager.address}`)

  await BetManager.write.setCreationFee([parseUnits('100', 18)])
  console.log(`Bet creation fee has been set for BetManager.`)

  await BetVotingEscrow.write.setBetManager([BetManager.address])
  console.log(`BetManager added to BetVotingEscrow.`)
  await BetVotingEscrow.write.setGovTokenStaking([GovTokenStaking.address])
  console.log(`GovTokenStaking added to BetVotingEscrow.`)

  await writeJson('./contracts.json', contracts)
})
