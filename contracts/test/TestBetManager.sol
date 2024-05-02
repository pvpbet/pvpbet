// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TestBetManager {
  mapping(address bet => bool) private _betMap;

  function setBet(address bet)
  external {
    _betMap[bet] = true;
  }

  function isBet(address bet)
  external view
  returns (bool) {
    return _betMap[bet];
  }
}
