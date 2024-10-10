import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { GovTokenStakingImplModule } from '../GovTokenStaking'

export default buildModule('GovTokenStakingUpgrade', m => {
  const { GovTokenStakingImpl } = m.useModule(GovTokenStakingImplModule)
  const GovTokenStaking = m.contractAt('GovTokenStaking', m.getParameter('proxy'))
  m.call(GovTokenStaking, 'upgradeToAndCall', [GovTokenStakingImpl, '0x'])
  const VotingEscrow = m.contractAt('VotingEscrow', m.getParameter('VotingEscrow'))
  m.call(VotingEscrow, 'setGovTokenStaking', [GovTokenStaking])
  return { GovTokenStaking }
})
