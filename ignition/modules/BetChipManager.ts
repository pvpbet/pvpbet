import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'
import BetChipFactoryModule from './BetChipFactory'

export default buildModule('BetChipManager', m => {
  const { BetChipFactory } = m.useModule(BetChipFactoryModule)

  const implementation = m.contract(
    'BetChipManager',
    [],
    {
      id: 'BetChipManagerImpl',
    },
  )
  const initialize = m.encodeFunctionCall(
    implementation,
    'initialize(address)',
    [BetChipFactory],
  )
  const proxy = m.contract('ERC1967Proxy', [implementation, initialize])
  const BetChipManager = m.contractAt('BetChipManager', proxy)
  return { BetChipManager }
})
