import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetChip', m => {
  const BetChip = m.contract('BetChip', [
    m.getParameter('currency'),
  ])
  return { BetChip }
})
