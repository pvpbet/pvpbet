import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { BetChipFactoryModule } from '../BetChipManager'

export default buildModule('BetChipFactoryUpgrade', m => {
  const { BetChipFactory } = m.useModule(BetChipFactoryModule)
  const BetChipManager = m.contractAt('BetChipManager', m.getParameter('BetChipManager'))
  m.call(BetChipManager, 'setBetChipFactory', [BetChipFactory])
  return { BetChipFactory }
})
