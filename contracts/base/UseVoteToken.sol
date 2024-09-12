// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IErrors} from "../interface/IErrors.sol";
import {IUseVoteToken} from "../interface/IUseVoteToken.sol";

abstract contract UseVoteToken is IUseVoteToken, IErrors {
  address private _voteToken;

  function _authorizeUpdateVoteToken(address sender)
  internal virtual;

  modifier onlyVoteContract() virtual {
    if (msg.sender != _voteToken) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function voteToken()
  public view virtual
  returns (address) {
    return _voteToken;
  }

  function setVoteToken(address newVoteToken)
  external virtual {
    _authorizeUpdateVoteToken(msg.sender);
    _setVoteToken(newVoteToken);
  }

  function _setVoteToken(address newVoteToken)
  internal {
    _voteToken = newVoteToken;
    emit VoteTokenSet(newVoteToken);
  }
}
