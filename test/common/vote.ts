import { ignition } from 'hardhat'
import BetVotingEscrowModule from '../../ignition/modules/BetVotingEscrow'

export async function deployBetVotingEscrow() {
  const { BetVotingEscrow } = await ignition.deploy(BetVotingEscrowModule)
  return BetVotingEscrow
}
