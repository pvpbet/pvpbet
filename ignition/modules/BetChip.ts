import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetChip', m => {
  const implementation = m.contract(
    'BetChip',
    [],
    {
      id: 'BetChipImpl',
    },
  )
  const initialize = m.encodeFunctionCall(
    implementation,
    'initialize(address[],uint256[])',
    [
      m.getParameter('currencies'),
      m.getParameter('rates'),
    ],
  )
  const proxy = m.contract('ERC1967Proxy', [implementation, initialize])
  const BetChip = m.contractAt('BetChip', proxy)
  return { BetChip }
})
