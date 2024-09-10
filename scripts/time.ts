import { time } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { exec } from '../utils'

const WEEK = 3600 * 24 * 7
const WEEK12 = WEEK * 12

exec(async () => {
  const seconds = WEEK
  await time.increase(seconds)
  console.log(`Time increased by ${seconds} seconds`)
})
