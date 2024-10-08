import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetVotingEscrowUpgrade', m => {
  const implementation = m.contract(
    'BetVotingEscrow',
    [],
    {
      id: 'BetVotingEscrowImpl',
    },
  )
  const BetVotingEscrow = m.contractAt('BetVotingEscrow', m.getParameter('proxy'))
  m.call(BetVotingEscrow, 'upgradeToAndCall', [implementation, '0x'])
  return { BetVotingEscrow }
})
