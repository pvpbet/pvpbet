import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetGovToken', (m) => {
  const BetGovToken = m.contract('BetGovToken')
  return { BetGovToken }
})
