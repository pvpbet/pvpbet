import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { BetConfiguratorModule } from '../BetManager'

export default buildModule('BetConfiguratorUpgrade', m => {
  const { BetConfigurator } = m.useModule(BetConfiguratorModule)
  const BetManager = m.contractAt('BetManager', m.getParameter('BetManager'))
  m.call(BetManager, 'setBetConfigurator', [BetConfigurator])
  return { BetConfigurator }
})
