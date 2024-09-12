// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IErrors} from "../interface/IErrors.sol";
import {IUseChipToken} from "../interface/IUseChipToken.sol";

abstract contract UseChipToken is IUseChipToken, IErrors {
  address private _chipToken;

  function _authorizeUpdateChipToken(address sender)
  internal virtual;

  modifier onlyChipContract() virtual {
    if (msg.sender != _chipToken) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function chipToken()
  public view virtual
  returns (address) {
    return _chipToken;
  }

  function setChipToken(address newChipToken)
  external virtual {
    _authorizeUpdateChipToken(msg.sender);
    _setChipToken(newChipToken);
  }

  function _setChipToken(address newChipToken)
  internal {
    _chipToken = newChipToken;
    emit ChipTokenSet(newChipToken);
  }
}
