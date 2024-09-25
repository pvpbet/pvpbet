// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBetOptionFactory} from "./interface/IBetOptionFactory.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {BetOption} from "./BetOption.sol";

contract BetOptionFactory is IBetOptionFactory, IMetadata {
  function name()
  public pure
  returns (string memory) {
    return "PVPBetOptionFactory";
  }

  function version()
  public pure
  returns (string memory) {
    return "1.0.0";
  }

  function createBetOption(
    string calldata description,
    address bet
  ) external returns (address) {
    return address(
      new BetOption(
        version(),
        description,
        bet
      )
    );
  }
}
