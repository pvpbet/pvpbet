import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('GovTokenStakingUpgrade', m => {
  const implementation = m.contract(
    'GovTokenStaking',
    [],
    {
      id: 'GovTokenStakingImpl',
    },
  )
  const GovTokenStaking = m.contractAt('GovTokenStaking', m.getParameter('proxy'))
  m.call(GovTokenStaking, 'upgradeToAndCall', [implementation, '0x'])
  return { GovTokenStaking }
})
