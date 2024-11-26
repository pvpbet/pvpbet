// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUseGovTokenStaking {
  event GovTokenStakingSet(address govTokenStaking);

  /**
   * @dev Returns the contract address of the governance token staking.
   */
  function govTokenStaking() external view returns (address);

  /**
   * @dev Sets the contract address of the governance token staking.
   *
   * Can only be called by the authorized.
   */
  function setGovTokenStaking(address newGovTokenStaking) external;
}
