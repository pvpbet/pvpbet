import { time } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers'
import { exec } from '../utils'

const HOUR = 3600
const DAY = HOUR * 24
const WEEK = DAY * 7
const WEEK12 = WEEK * 12

exec(async () => {
  const seconds = HOUR * 60
  await time.increase(seconds)
  console.log(`Time increased by ${seconds} seconds`)
})
