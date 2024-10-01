// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IErrors} from "../interface/IErrors.sol";
import {IUseGovTokenStaking} from "../interface/IUseGovTokenStaking.sol";

abstract contract UseGovTokenStaking is IUseGovTokenStaking, IErrors {
  address private _govTokenStaking;

  function _authorizeUpdateGovTokenStaking(address sender)
  internal virtual;

  modifier onlyGovTokenStaking() {
    if (msg.sender != _govTokenStaking) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function govTokenStaking()
  public view virtual
  returns (address) {
    return _govTokenStaking;
  }

  function setGovTokenStaking(address newGovTokenStaking)
  external virtual {
    _authorizeUpdateGovTokenStaking(msg.sender);
    _setGovTokenStaking(newGovTokenStaking);
  }

  function _setGovTokenStaking(address newGovTokenStaking)
  internal virtual {
    _govTokenStaking = newGovTokenStaking;
    emit GovTokenStakingSet(newGovTokenStaking);
  }
}
