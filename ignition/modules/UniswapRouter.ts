import { buildModule } from '@nomicfoundation/hardhat-ignition/modules'

export default buildModule('UniswapRouter', m => {
  const UniswapRouter = m.contract('UniswapRouter', [
    m.getParameter('swapRouter'),
  ])
  return { UniswapRouter }
})
