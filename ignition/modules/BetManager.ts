import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export const BetManagerImplModule = buildModule('BetManagerImpl', m => {
  const BetManagerImpl = m.contract(
    'BetManager',
    [],
    {
      id: 'BetManagerImpl',
    },
  )
  return { BetManagerImpl }
})

export const BetConfiguratorModule = buildModule('BetConfigurator', m => {
  const BetConfigurator = m.contract('BetConfigurator')
  return { BetConfigurator }
})

export const BetFactoryModule = buildModule('BetFactory', m => {
  const BetFactory = m.contract('BetFactory')
  return { BetFactory }
})

export const BetOptionFactoryModule = buildModule('BetOptionFactory', m => {
  const BetOptionFactory = m.contract('BetOptionFactory')
  return { BetOptionFactory }
})

export default buildModule('BetManager', m => {
  const { BetManagerImpl } = m.useModule(BetManagerImplModule)
  const { BetConfigurator } = m.useModule(BetConfiguratorModule)
  const { BetFactory } = m.useModule(BetFactoryModule)
  const { BetOptionFactory } = m.useModule(BetOptionFactoryModule)

  const initialize = m.encodeFunctionCall(
    BetManagerImpl,
    'initialize(address,address,address,address,address,address)',
    [
      m.getParameter('BetChipManager'),
      BetConfigurator,
      BetFactory,
      BetOptionFactory,
      m.getParameter('VotingEscrow'),
      m.getParameter('GovToken'),
    ],
  )
  const proxy = m.contract('ERC1967Proxy', [BetManagerImpl, initialize])
  const BetManager = m.contractAt('BetManager', proxy)
  return { BetManager, BetConfigurator, BetFactory, BetOptionFactory }
})
