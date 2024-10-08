import { ignition } from 'hardhat'
import VotingEscrowModule from '../../ignition/modules/VotingEscrow'

export async function deployVotingEscrow() {
  const { VotingEscrow } = await ignition.deploy(VotingEscrowModule)
  return VotingEscrow
}
