import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('ContractSetup', m => {
  const BetManager = m.contractAt('BetManager', m.getParameter('BetManager'))
  const BetConfigurator = m.contractAt('BetConfigurator', m.getParameter('BetConfigurator'))
  const BetVotingEscrow = m.contractAt('BetVotingEscrow', m.getParameter('BetVotingEscrow'))

  m.call(BetManager, 'setCreationFee', [m.getParameter('creationFee')])
  m.call(BetConfigurator, 'setOriginAllowlist', [m.getParameter('originAllowlist')])
  m.call(BetVotingEscrow, 'setGovTokenStaking', [m.getParameter('GovTokenStaking')])

  return {}
})
