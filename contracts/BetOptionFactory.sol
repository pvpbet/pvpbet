// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
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

  address private _implementation;

  function createBetOption(
    string calldata description,
    address bet,
    address chip,
    address vote,
    uint256 chipPerQuantity,
    uint256 votePerQuantity
  ) external returns (address) {
    BetOption betOption;
    if (_implementation == address(0)) {
      betOption = new BetOption();
      _implementation = address(betOption);
    } else {
      betOption = BetOption(payable(Clones.clone(_implementation)));
    }
    betOption.initialize(
      version(),
      description,
      bet,
      chip,
      vote,
      chipPerQuantity,
      votePerQuantity
    );
    return address(betOption);
  }
}
