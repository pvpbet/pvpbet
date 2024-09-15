import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('ContractSetup', m => {
  const BetManager = m.contractAt('BetManager', m.getParameter('BetManager'))
  const BetVotingEscrow = m.contractAt('BetVotingEscrow', m.getParameter('BetVotingEscrow'))

  m.call(BetManager, 'setCreationFee', [m.getParameter('creationFee')])
  m.call(BetManager, 'setOriginAllowlist', [m.getParameter('originAllowlist')])
  m.call(BetVotingEscrow, 'setBetManager', [m.getParameter('BetManager')])
  m.call(BetVotingEscrow, 'setGovTokenStaking', [m.getParameter('GovTokenStaking')])

  return {}
})
