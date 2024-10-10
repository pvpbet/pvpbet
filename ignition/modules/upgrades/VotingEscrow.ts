import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { VotingEscrowImplModule } from '../VotingEscrow'

export default buildModule('VotingEscrowUpgrade', m => {
  const { VotingEscrowImpl } = m.useModule(VotingEscrowImplModule)
  const VotingEscrow = m.contractAt('VotingEscrow', m.getParameter('proxy'))
  m.call(VotingEscrow, 'upgradeToAndCall', [VotingEscrowImpl, '0x'])
  return { VotingEscrow }
})
