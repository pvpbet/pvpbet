import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetChip', m => {
  const BetChip = m.contractAt('BetChip', m.getParameter('chip'))
  return { BetChip }
})
