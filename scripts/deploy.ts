import { viem, ignition } from 'hardhat'
import { parseUnits } from 'viem'
import { exec } from '../utils'
import BetGovTokenModule from '../ignition/modules/BetGovToken'
import BetChipModule from '../ignition/modules/BetChip'
import BetVotingEscrowModule from '../ignition/modules/BetVotingEscrow'
import BetManagerModule from '../ignition/modules/BetManager'

exec(async () => {
  const USDC = await viem.deployContract('USDC')
  await USDC.write.mint([parseUnits('10000000000', 6)])
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
  console.log(`BetChip deployed to: ${BetChip.address}`)

  const { BetGovToken } = await ignition.deploy(BetGovTokenModule)
  console.log(`BetGovToken deployed to: ${BetGovToken.address}`)

  const { BetVotingEscrow } = await ignition.deploy(BetVotingEscrowModule, {
    parameters: {
      BetVotingEscrow: {
        govToken: BetGovToken.address,
      },
    },
  })
  console.log(`BetVotingEscrow deployed to: ${BetVotingEscrow.address}`)

  const { BetManager } = await ignition.deploy(BetManagerModule, {
    parameters: {
      BetManager: {
        chip: BetChip.address,
        vote: BetVotingEscrow.address,
        govToken: BetGovToken.address,
      },
    },
  })
  console.log(`BetManager deployed to: ${BetManager.address}`)

  await BetVotingEscrow.write.setBetManager([BetManager.address])
  console.log(`BetManager added to BetVotingEscrow`)
})
