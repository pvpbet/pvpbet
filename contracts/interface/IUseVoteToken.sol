// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseVoteToken {
  event SetVoteToken(address voteToken);

  /**
   * @dev Returns the vote token contract address.
   */
  function voteToken() external view returns (address);

  /**
   * @dev Set the vote token contract address.
   */
  function setVoteToken(address newVote) external;
}
