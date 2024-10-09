import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetManagerUpgrade', m => {
  const implementation = m.contract(
    'BetManager',
    [],
    {
      id: 'BetManagerImpl',
    },
  )
  const BetManager = m.contractAt('BetManager', m.getParameter('proxy'))
  m.call(BetManager, 'upgradeToAndCall', [implementation, '0x'])
  return { BetManager }
})
