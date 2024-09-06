import { viem, ignition } from 'hardhat'
import { parseUnits } from 'viem'
import { exec } from '../utils'
import GovTokenModule from '../ignition/modules/GovToken'
import GovTokenStakingModule from '../ignition/modules/GovTokenStaking'
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

  const { BetVotingEscrow } = await ignition.deploy(BetVotingEscrowModule)
  console.log(`BetVotingEscrow deployed to: ${BetVotingEscrow.address}`)

  const { GovToken } = await ignition.deploy(GovTokenModule)
  console.log(`GovToken deployed to: ${GovToken.address}`)

  const { GovTokenStaking } = await ignition.deploy(GovTokenStakingModule, {
    parameters: {
      GovTokenStaking: {
        govToken: GovToken.address,
        voteToken: BetVotingEscrow.address,
      },
    },
  })
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
  console.log(`BetManager deployed to: ${BetManager.address}`)

  await BetVotingEscrow.write.setBetManager([BetManager.address])
  console.log(`BetManager added to BetVotingEscrow`)
  await BetVotingEscrow.write.setGovTokenStaking([GovTokenStaking.address])
  console.log(`GovTokenStaking added to BetVotingEscrow`)
})
