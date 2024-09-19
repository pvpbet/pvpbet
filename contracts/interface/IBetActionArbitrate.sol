// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Record} from "../lib/Record.sol";

interface IBetActionArbitrate {
  event Arbitrated(address indexed arbitrator, uint256 amount);

  /**
   * @dev Arbitrators to arbitrate.
   */
  function arbitrate(uint256 amount) external;

  /**
   * @dev Arbitrators to arbitrate through the vote contract.
   *
   * Can only be called by the vote contract.
   */
  function arbitrate(address arbitrator, uint256 amount) external;

  /**
   * @dev Returns the total arbitrated amount.
   */
  function arbitratedAmount() external view returns (uint256);

  /**
   * @dev Returns the arbitrated amount of the arbitrator.
   */
  function arbitratedAmount(address arbitrator) external view returns (uint256);

  /**
   * @dev Returns the records of the arbitration.
   */
  function arbitratedRecords() external view returns (Record[] memory);
}
