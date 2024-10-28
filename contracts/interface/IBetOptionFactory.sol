// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";

interface IBetOptionFactory {
  /**
	 * @dev Creates a bet option.
	 */
  function createBetOption(
    string calldata description,
    IBet.BetConfig calldata config,
    address bet,
    address chip,
    address vote
  ) external returns (address);
}
