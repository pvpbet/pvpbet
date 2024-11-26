// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseVotingEscrow {
  event VotingEscrowSet(address votingEscrow);

  /**
   * @dev Returns the contract address of the voting escrow.
   */
  function votingEscrow() external view returns (address);

  /**
   * @dev Sets the contract address of the voting escrow.
   *
   * Can only be called by the authorized.
   */
  function setVotingEscrow(address newVotingEscrow) external;
}
