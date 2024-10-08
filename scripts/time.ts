import { time } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { exec } from '../utils'

const HOUR = 3600
const DAY = HOUR * 24

exec(async () => {
  const seconds = DAY * 2.5
  await time.increase(seconds)
  console.log(`Time increased by ${seconds} seconds`)
})
