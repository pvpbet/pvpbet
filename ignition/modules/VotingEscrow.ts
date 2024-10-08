import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('VotingEscrow', m => {
  const implementation = m.contract(
    'VotingEscrow',
    [],
    {
      id: 'VotingEscrowImpl',
    },
  )
  const initialize = m.encodeFunctionCall(
    implementation,
    'initialize',
  )
  const proxy = m.contract('ERC1967Proxy', [implementation, initialize])
  const VotingEscrow = m.contractAt('VotingEscrow', proxy)
  return { VotingEscrow }
})
