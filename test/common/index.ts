import { ignition, viem } from 'hardhat'
import GovTokenModule from '../../ignition/modules/GovToken'
import {
  parseEther,
  parseUnits,
} from 'viem'
import type { Address } from 'viem'
import type { WalletClient } from '@nomicfoundation/hardhat-viem/types'
import type { ContractTypes } from '../../types'

export interface TestTokens {
  DAI: ContractTypes['DAI']
  USDC: ContractTypes['USDC']
}

export async function deployTestTokens(): Promise<TestTokens> {
  const DAI = await viem.deployContract('DAI')
  const USDC = await viem.deployContract('USDC')
  return {
    DAI,
    USDC,
  }
}

export async function claimTestTokens(
  owner: WalletClient,
  { DAI, USDC }: TestTokens,
) {
  await DAI.write.mint(
    [parseUnits('1000000', 18)],
    { account: owner.account },
  )
  await USDC.write.mint(
    [parseUnits('1000000', 6)],
    { account: owner.account },
  )
}

export async function depositAssets(
  owner: WalletClient,
  address: Address,
  { DAI, USDC }: TestTokens,
) {
  await owner.sendTransaction({ to: address, value: parseEther('100') })
  await DAI.write.transfer(
    [address, parseUnits('1000000', 18)],
    { account: owner.account },
  )
  await USDC.write.transfer(
    [address, parseUnits('1000000', 6)],
    { account: owner.account },
  )
}

export async function deployGovToken() {
  const { GovToken } = await ignition.deploy(GovTokenModule)
  return GovToken
}
