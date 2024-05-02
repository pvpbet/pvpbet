import type { GetContractReturnType } from '@nomicfoundation/hardhat-viem/types'
import type { ArtifactsMap } from 'hardhat/types'

export interface ContractTypes {
  DAI: GetContractReturnType<ArtifactsMap['DAI']['abi']>
  USDC: GetContractReturnType<ArtifactsMap['USDC']['abi']>
  Bet: GetContractReturnType<ArtifactsMap['Bet']['abi']>
  BetChip: GetContractReturnType<ArtifactsMap['BetChip']['abi']>
  BetFactory: GetContractReturnType<ArtifactsMap['BetFactory']['abi']>
  BetManager: GetContractReturnType<ArtifactsMap['BetManager']['abi']>
  BetOption: GetContractReturnType<ArtifactsMap['BetOption']['abi']>
  BetOptionFactory: GetContractReturnType<ArtifactsMap['BetOptionFactory']['abi']>
  BetGovToken: GetContractReturnType<ArtifactsMap['BetGovToken']['abi']>
  BetVotingEscrow: GetContractReturnType<ArtifactsMap['BetVotingEscrow']['abi']>
  Receivable: GetContractReturnType<ArtifactsMap['Receivable']['abi']>
  Withdrawable: GetContractReturnType<ArtifactsMap['Withdrawable']['abi']>
}
