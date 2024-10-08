import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('VotingEscrowUpgrade', m => {
  const implementation = m.contract(
    'VotingEscrow',
    [],
    {
      id: 'VotingEscrowImpl',
    },
  )
  const VotingEscrow = m.contractAt('VotingEscrow', m.getParameter('proxy'))
  m.call(VotingEscrow, 'upgradeToAndCall', [implementation, '0x'])
  return { VotingEscrow }
})
