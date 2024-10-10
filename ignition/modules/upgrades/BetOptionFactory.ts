import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { BetOptionFactoryModule } from '../BetManager'

export default buildModule('BetOptionFactoryUpgrade', m => {
  const { BetOptionFactory } = m.useModule(BetOptionFactoryModule)
  const BetManager = m.contractAt('BetManager', m.getParameter('BetManager'))
  m.call(BetManager, 'setBetOptionFactory', [BetOptionFactory])
  return { BetOptionFactory }
})
