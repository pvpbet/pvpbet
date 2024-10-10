import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export const GovTokenStakingImplModule = buildModule('GovTokenStakingImpl', m => {
  const GovTokenStakingImpl = m.contract(
    'GovTokenStaking',
    [],
    {
      id: 'GovTokenStakingImpl',
    },
  )
  return { GovTokenStakingImpl }
})

export default buildModule('GovTokenStaking', m => {
  const { GovTokenStakingImpl } = m.useModule(GovTokenStakingImplModule)
  const VotingEscrow = m.contractAt('VotingEscrow', m.getParameter('VotingEscrow'))

  const initialize = m.encodeFunctionCall(
    GovTokenStakingImpl,
    'initialize(address,address,address[])',
    [
      VotingEscrow,
      m.getParameter('GovToken'),
      m.getParameter('rewardTokens'),
    ],
  )
  const proxy = m.contract('ERC1967Proxy', [GovTokenStakingImpl, initialize])
  const GovTokenStaking = m.contractAt('GovTokenStaking', proxy)
  m.call(VotingEscrow, 'setGovTokenStaking', [GovTokenStaking])
  return { GovTokenStaking }
})
