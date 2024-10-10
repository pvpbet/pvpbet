import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export const BetChipManagerImplModule = buildModule('BetChipManagerImpl', m => {
  const BetChipManagerImpl = m.contract(
    'BetChipManager',
    [],
    {
      id: 'BetChipManagerImpl',
    },
  )
  return { BetChipManagerImpl }
})

export const BetChipFactoryModule = buildModule('BetChipFactory', m => {
  const BetChipFactory = m.contract('BetChipFactory')
  return { BetChipFactory }
})

export default buildModule('BetChipManager', m => {
  const { BetChipManagerImpl } = m.useModule(BetChipManagerImplModule)
  const { BetChipFactory } = m.useModule(BetChipFactoryModule)

  const initialize = m.encodeFunctionCall(
    BetChipManagerImpl,
    'initialize(address)',
    [BetChipFactory],
  )
  const proxy = m.contract('ERC1967Proxy', [BetChipManagerImpl, initialize])
  const BetChipManager = m.contractAt('BetChipManager', proxy)
  return { BetChipManager }
})
