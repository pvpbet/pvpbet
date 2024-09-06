// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUseBetManager} from "../interface/IUseBetManager.sol";
import {IBetManager} from "../interface/IBetManager.sol";
import {IErrors} from "../interface/IErrors.sol";

abstract contract UseBetManager is IUseBetManager, IErrors {
  address private _betManager;

  function _authorizeUpdateBetManager(address sender)
  internal virtual;

  modifier onlyBet() {
    if (_betManager == address(0) || !IBetManager(_betManager).isBet(msg.sender)) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function betManager()
  public view virtual
  returns (address) {
    return _betManager;
  }

  function setBetManager(address newBetManager)
  external virtual {
    _authorizeUpdateBetManager(msg.sender);
    _setBetManager(newBetManager);
  }

  function _setBetManager(address newBetManager)
  private {
    _betManager = newBetManager;
    emit SetBetManager(newBetManager);
  }
}
