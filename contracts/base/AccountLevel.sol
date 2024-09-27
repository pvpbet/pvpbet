// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccountLevel} from "../interface/IAccountLevel.sol";
import {MathLib} from "../lib/Math.sol";

abstract contract AccountLevel is IAccountLevel {
  using MathLib for uint256;

  mapping(address account => uint256) private _levels;

  function _authorizeUpdateAccountLevel(address sender)
  internal virtual;

  function level(address account)
  public view
  returns (uint256) {
    return _levels[account];
  }

  function levelUp(address account)
  external {
    _authorizeUpdateAccountLevel(msg.sender);
    _levels[account] = _levels[account].inc();
    emit LevelUpdated(account, _levels[account]);
  }

  function levelUpBatch(address[] calldata accounts)
  external {
    _authorizeUpdateAccountLevel(msg.sender);
    uint256 length = accounts.length;
    uint256[] memory levels = new uint256[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address account = accounts[i];
      levels[i] = _levels[account] = _levels[account].inc();
    }
    emit LevelUpdatedBatch(accounts, levels);
  }

  function levelDown(address account)
  external {
    _authorizeUpdateAccountLevel(msg.sender);
    _levels[account] = _levels[account].sub(3);
    emit LevelUpdated(account, _levels[account]);
  }

  function levelDownBatch(address[] calldata accounts)
  external {
    _authorizeUpdateAccountLevel(msg.sender);
    uint256 length = accounts.length;
    uint256[] memory levels = new uint256[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address account = accounts[i];
      levels[i] = _levels[account] = _levels[account].sub(3);
    }
    emit LevelUpdatedBatch(accounts, levels);
  }
}
