import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetChipFactory', m => {
  const BetChipFactory = m.contract('BetChipFactory')
  return { BetChipFactory }
})
