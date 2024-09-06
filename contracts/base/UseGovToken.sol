// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUseGovToken} from "../interface/IUseGovToken.sol";

abstract contract UseGovToken is IUseGovToken {
  address private _govToken;

  function _authorizeUpdateGovToken(address sender)
  internal virtual;

  function govToken()
  public view virtual
  returns (address) {
    return _govToken;
  }

  function setGovToken(address newGovToken)
  external virtual {
    _authorizeUpdateGovToken(msg.sender);
    _setGovToken(newGovToken);
  }

  function _setGovToken(address newGovToken)
  internal {
    _govToken = newGovToken;
    emit SetGovToken(newGovToken);
  }
}
