import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { BetChipManagerImplModule } from '../BetChipManager'

export default buildModule('BetChipManagerUpgrade', m => {
  const { BetChipManagerImpl } = m.useModule(BetChipManagerImplModule)
  const BetChipManager = m.contractAt('BetChipManager', m.getParameter('proxy'))
  m.call(BetChipManager, 'upgradeToAndCall', [BetChipManagerImpl, '0x'])
  return { BetChipManager }
})
