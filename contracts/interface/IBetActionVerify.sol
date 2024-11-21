// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Record} from "../lib/Record.sol";

interface IBetActionVerify {
  event Verified(address indexed verifier, uint256 amount);

  /**
   * @dev Verifiers to verify.
   */
  function verify(uint256 amount) external;

  /**
   * @dev Verifiers to verify through the vote contract.
   *
   * Can only be called by the vote contract.
   */
  function verify(address verifier, uint256 amount) external;

  /**
   * @dev Returns the vote minimum value.
   *
   * If it is below this value, it will be considered a dust attack.
   */
  function voteMinValue() external view returns (uint256);

  /**
   * @dev Returns the total verified amount.
   */
  function verifiedAmount() external view returns (uint256);

  /**
   * @dev Returns the verified amount of the verifier.
   */
  function verifiedAmount(address verifier) external view returns (uint256);

  /**
   * @dev Returns the records of the verification.
   */
  function verifiedRecords() external view returns (Record[] memory);

  /**
   * @dev Returns the records of the verification.
   */
  function verifiedRecords(uint256 offset, uint256 limit) external view returns (Record[] memory);

  /**
   * @dev Returns the count of the records of the verification.
   */
  function verifiedRecordCount() external view returns (uint256);

  /**
   * @dev Confiscates the verified votes into the bet contract.
   *
   * Can only be called by the bet contract.
   */
  function confiscateVerifiedVotes() external;

  /**
   * @dev Confiscates the verified votes into the bet contract.
   * @param limit The number of accounts processed at a time.
   *
   * Can only be called by the bet contract.
   */
  function confiscateVerifiedVotes(uint256 limit) external;

  /**
   * @dev Unfixes the verified votes to the verifiers.
   *
   * Can only be called by the bet contract.
   */
  function unfixVerifiedVotes() external;

  /**
   * @dev Unfixes the verified votes to the verifiers.
   * @param limit The number of accounts processed at a time.
   *
   * Can only be called by the bet contract.
   */
  function unfixVerifiedVotes(uint256 limit) external;

  /**
   * @dev Returns true if the verified votes has been released.
   */
  function verifiedVotesReleased() external view returns (bool);
}
