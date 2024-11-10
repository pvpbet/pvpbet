// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IBet} from "./interface/IBet.sol";
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
    return "1.0.4";
  }

  address private _implementation;

  function createBetOption(
    string calldata description,
    IBet.BetConfig calldata config,
    address bet,
    address chip,
    address vote
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
      config,
      bet,
      chip,
      vote
    );
    return address(betOption);
  }
}
