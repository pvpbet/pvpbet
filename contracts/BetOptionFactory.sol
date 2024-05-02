// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBetOptionFactory} from "./interface/IBetOptionFactory.sol";
import {BetOption} from "./BetOption.sol";

contract BetOptionFactory {
  function createBetOption(
    address bet,
    string calldata description
  ) external returns (address) {
    return address(
      new BetOption(
        bet,
        description
      )
    );
  }
}
