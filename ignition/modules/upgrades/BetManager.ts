import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import { BetManagerImplModule } from '../BetManager'

export default buildModule('BetManagerUpgrade', m => {
  const { BetManagerImpl } = m.useModule(BetManagerImplModule)
  const BetManager = m.contractAt('BetManager', m.getParameter('proxy'))
  m.call(BetManager, 'upgradeToAndCall', [BetManagerImpl, '0x'])
  return { BetManager }
})
