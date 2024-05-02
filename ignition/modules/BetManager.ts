import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export const BetFactoryModule = buildModule('BetFactory', (m) => {
  const BetFactory = m.contract('BetFactory')
  return { BetFactory }
})

export const BetOptionFactoryModule = buildModule('BetOptionFactory', (m) => {
  const BetOptionFactory = m.contract('BetOptionFactory')
  return { BetOptionFactory }
})

export default buildModule('BetManager', (m) => {
  const { BetFactory } = m.useModule(BetFactoryModule)
  const { BetOptionFactory } = m.useModule(BetOptionFactoryModule)

  const implementation = m.contract(
    'BetManager',
    [],
    {
      id: 'BetManagerImpl',
    }
  )
  const initialize = m.encodeFunctionCall(
    implementation,
    'initialize(address,address,address,address,address)',
    [
      BetFactory,
      BetOptionFactory,
      m.getParameter('chip'),
      m.getParameter('vote'),
      m.getParameter('govToken'),
    ],
  )
  const proxy = m.contract('ERC1967Proxy', [implementation, initialize])
  const BetManager = m.contractAt('BetManager', proxy)
  return { BetManager, BetFactory, BetOptionFactory }
})
