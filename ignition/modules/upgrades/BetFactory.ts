import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { BetFactoryModule } from '../BetManager'

export default buildModule('BetFactoryUpgrade', m => {
  const { BetFactory } = m.useModule(BetFactoryModule)
  const BetManager = m.contractAt('BetManager', m.getParameter('BetManager'))
  m.call(BetManager, 'setBetFactory', [BetFactory])
  return { BetFactory }
})
