import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetProxy', m => {
  const BetProxy = m.contract('BetProxy')
  return { BetProxy }
})
