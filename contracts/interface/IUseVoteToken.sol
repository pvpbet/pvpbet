// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseVoteToken {
  event VoteTokenSet(address voteToken);

  /**
   * @dev Returns the contract address of the vote token.
   */
  function voteToken() external view returns (address);

  /**
   * @dev Set the contract address of the vote token.
   */
  function setVoteToken(address newVote) external;
}
