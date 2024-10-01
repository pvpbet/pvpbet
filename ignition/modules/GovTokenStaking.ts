import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('GovTokenStaking', m => {
  const implementation = m.contract(
    'GovTokenStaking',
    [],
    {
      id: 'GovTokenStakingImpl',
    },
  )
  const initialize = m.encodeFunctionCall(
    implementation,
    'initialize(address,address,address[])',
    [
      m.getParameter('govToken'),
      m.getParameter('voteToken'),
      m.getParameter('rewardTokens'),
    ],
  )
  const proxy = m.contract('ERC1967Proxy', [implementation, initialize])
  const GovTokenStaking = m.contractAt('GovTokenStaking', proxy)
  return { GovTokenStaking }
})
