import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetFactory', m => {
  const BetFactory = m.contract('BetFactory')
  return { BetFactory }
})
