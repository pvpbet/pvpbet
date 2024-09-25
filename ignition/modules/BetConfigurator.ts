import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('BetConfigurator', m => {
  const BetConfigurator = m.contract('BetConfigurator')
  return { BetConfigurator }
})
