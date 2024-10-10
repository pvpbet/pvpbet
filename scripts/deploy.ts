import { ignition, viem } from 'hardhat'
import { parseUnits, zeroAddress } from 'viem'
import { exec } from '../utils'
import { createBetChip } from '../test/common/chip'
import BetChipManagerModule from '../ignition/modules/BetChipManager'
import BetManagerModule from '../ignition/modules/BetManager'
import GovTokenModule from '../ignition/modules/GovToken'
import GovTokenStakingModule from '../ignition/modules/GovTokenStaking'
import VotingEscrowModule from '../ignition/modules/VotingEscrow'

exec(async () => {
  const [owner] = await viem.getWalletClients()

  const USDC = await viem.deployContract('USDC')
  await USDC.write.mint([parseUnits('10000000000', 6)])
  console.log(`USDC deployed to: ${USDC.address}`)

  const { BetChipManager } = await ignition.deploy(BetChipManagerModule)
  console.log(`BetChipManager deployed to: ${BetChipManager.address}`)

  const BetChip = await createBetChip(owner, BetChipManager, USDC.address)
  console.log(`BetChip deployed to: ${BetChip.address}`)

  const { VotingEscrow } = await ignition.deploy(VotingEscrowModule)
  console.log(`VotingEscrow deployed to: ${VotingEscrow.address}`)

  const { GovToken } = await ignition.deploy(GovTokenModule)
  console.log(`GovToken deployed to: ${GovToken.address}`)

  const { GovTokenStaking } = await ignition.deploy(GovTokenStakingModule, {
    parameters: {
      GovTokenStaking: {
        VotingEscrow: VotingEscrow.address,
        GovToken: GovToken.address,
        rewardTokens: [
          zeroAddress,
          BetChip.address,
        ],
      },
    },
  })
  console.log(`GovTokenStaking deployed to: ${GovTokenStaking.address}`)

  const { BetManager, BetConfigurator } = await ignition.deploy(BetManagerModule, {
    parameters: {
      BetManager: {
        BetChipManager: BetChipManager.address,
        VotingEscrow: VotingEscrow.address,
        GovToken: GovToken.address,
      },
    },
  })
  console.log(`BetManager deployed to: ${BetManager.address}`)
  console.log(`BetConfigurator deployed to: ${BetConfigurator.address}`)
})
