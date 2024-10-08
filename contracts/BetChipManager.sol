// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Upgradeable} from "./base/Upgradeable.sol";
import {IBetChipFactory} from "./interface/IBetChipFactory.sol";
import {IBetChipManager} from "./interface/IBetChipManager.sol";

contract BetChipManager is IBetChipManager, Upgradeable {
  function name()
  public pure override
  returns (string memory) {
    return "PVPBetChipManager";
  }

  function version()
  public pure override
  returns (string memory) {
    return "1.0.0";
  }

  address private _betChipFactory;
  mapping(address chip => bool) private _betChipMap;

  function initialize(address initialBetChipFactory)
  public
  initializer {
    initialize();
    _setBetChipFactory(initialBetChipFactory);
  }

  function betChipFactory()
  external view
  returns (address) {
    return _betChipFactory;
  }

  function setBetChipFactory(address newBetChipFactory)
  external
  onlyOwner {
    _setBetChipFactory(newBetChipFactory);
  }

  function _setBetChipFactory(address newBetChipFactory)
  private {
    _betChipFactory = newBetChipFactory;
    emit BetChipFactorySet(newBetChipFactory);
  }

  function createBetChip(address token)
  external
  onlyOwner
  returns (address) {
    address chip = IBetChipFactory(_betChipFactory).createBetChip(token);
    emit BetChipCreated(chip);
    _betChipMap[chip] = true;
    return chip;
  }

  function isBetChip(address chip)
  external view
  returns (bool) {
    return _betChipMap[chip];
  }
}
