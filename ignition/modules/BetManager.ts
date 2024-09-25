import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import BetConfiguratorModule from './BetConfigurator'
import BetFactoryModule from './BetFactory'
import BetOptionFactoryModule from './BetOptionFactory'

export default buildModule('BetManager', m => {
  const { BetConfigurator } = m.useModule(BetConfiguratorModule)
  const { BetFactory } = m.useModule(BetFactoryModule)
  const { BetOptionFactory } = m.useModule(BetOptionFactoryModule)

  const implementation = m.contract(
    'BetManager',
    [],
    {
      id: 'BetManagerImpl',
    },
  )
  const initialize = m.encodeFunctionCall(
    implementation,
    'initialize(address,address,address,address,address,address)',
    [
      BetConfigurator,
      BetFactory,
      BetOptionFactory,
      m.getParameter('govToken'),
      m.getParameter('chipToken'),
      m.getParameter('voteToken'),
    ],
  )
  const proxy = m.contract('ERC1967Proxy', [implementation, initialize])
  const BetManager = m.contractAt('BetManager', proxy)
  return { BetManager, BetConfigurator, BetFactory, BetOptionFactory }
})
