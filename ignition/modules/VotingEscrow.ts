import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export const VotingEscrowImplModule = buildModule('VotingEscrowImpl', m => {
  const VotingEscrowImpl = m.contract(
    'VotingEscrow',
    [],
    {
      id: 'VotingEscrowImpl',
    },
  )
  return { VotingEscrowImpl }
})

export default buildModule('VotingEscrow', m => {
  const { VotingEscrowImpl } = m.useModule(VotingEscrowImplModule)

  const initialize = m.encodeFunctionCall(
    VotingEscrowImpl,
    'initialize',
  )
  const proxy = m.contract('ERC1967Proxy', [VotingEscrowImpl, initialize])
  const VotingEscrow = m.contractAt('VotingEscrow', proxy)
  return { VotingEscrow }
})
