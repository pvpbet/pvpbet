import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('TestUSDC', m => {
  const USDC = m.contract('USDC')
  return { USDC }
})
