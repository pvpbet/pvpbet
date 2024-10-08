import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetChipManagerUpgrade', m => {
  const implementation = m.contract(
    'BetChipManager',
    [],
    {
      id: 'GovTokenStakingImpl',
    },
  )
  const BetChipManager = m.contractAt('BetChipManager', m.getParameter('proxy'))
  m.call(BetChipManager, 'upgradeToAndCall', [implementation, '0x'])
  return { BetChipManager }
})
