// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Record} from "../lib/Record.sol";

interface IBetActionDispute {
  event Disputed(address indexed disputer, uint256 amount);

  /**
   * @dev Disputers to dispute.
   */
  function dispute(uint256 amount) external;

  /**
   * @dev Disputers to dispute through the chip contract.
   *
   * Can only be called by the chip contract.
   */
  function dispute(address disputer, uint256 amount) external;

  /**
   * @dev Returns the total disputed amount.
   */
  function disputedAmount() external view returns (uint256);

  /**
   * @dev Returns the disputed amount of the disputer.
   */
  function disputedAmount(address disputer) external view returns (uint256);

  /**
   * @dev Returns the records of the dispute.
   */
  function disputedRecords() external view returns (Record[] memory);

  /**
   * @dev Returns the records of the dispute.
   */
  function disputedRecords(uint256 offset, uint256 limit) external view returns (Record[] memory);

  /**
   * @dev Returns the count of the records of the dispute.
   */
  function disputedRecordCount() external view returns (uint256);

  /**
   * @dev Collects the disputed chips into the bet contract.
   *
   * Can only be called by the bet contract.
   */
  function collectDisputedChips() external;

  /**
   * @dev Refunds the disputed chips to the disputers.
   *
   * Can only be called by the bet contract.
   */
  function refundDisputedChips() external;

  /**
   * @dev Refunds the disputed chips to the disputers.
   * @param limit The number of accounts processed at a time.
   *
   * Can only be called by the bet contract.
   */
  function refundDisputedChips(uint256 limit) external;

  /**
   * @dev Returns true if the disputed chips has been released.
   */
  function disputedChipsReleased() external view returns (bool);
}
