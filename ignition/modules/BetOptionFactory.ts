import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetOptionFactory', m => {
  const BetOptionFactory = m.contract('BetOptionFactory')
  return { BetOptionFactory }
})
