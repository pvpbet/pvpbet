import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetVotingEscrow', m => {
  const implementation = m.contract(
    'BetVotingEscrow',
    [],
    {
      id: 'BetVotingEscrowImpl',
    },
  )
  const initialize = m.encodeFunctionCall(
    implementation,
    'initialize',
  )
  const proxy = m.contract('ERC1967Proxy', [implementation, initialize])
  const BetVotingEscrow = m.contractAt('BetVotingEscrow', proxy)
  return { BetVotingEscrow }
})
