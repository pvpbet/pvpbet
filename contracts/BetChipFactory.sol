// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBetChipFactory} from "./interface/IBetChipFactory.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {BetChip} from "./BetChip.sol";

contract BetChipFactory is IBetChipFactory, IMetadata {
  function name()
  public pure
  returns (string memory) {
    return "PVPBetChipFactory";
  }

  function version()
  public pure
  returns (string memory) {
    return "1.0.2";
  }

  function createBetChip(address token) external returns (address) {
    return address(
      new BetChip(version(), token)
    );
  }
}
