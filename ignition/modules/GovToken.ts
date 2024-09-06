import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('GovToken', m => {
  const GovToken = m.contract('GovToken')
  return { GovToken }
})
