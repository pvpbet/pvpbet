// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IErrors} from "../interface/IErrors.sol";
import {IUseVotingEscrow} from "../interface/IUseVotingEscrow.sol";

abstract contract UseVotingEscrow is IUseVotingEscrow, IErrors {
  address private _votingEscrow;

  function _authorizeUpdateVotingEscrow(address sender)
  internal virtual;

  modifier onlyVotingEscrow() virtual {
    if (msg.sender != _votingEscrow) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function votingEscrow()
  public view virtual
  returns (address) {
    return _votingEscrow;
  }

  function setVotingEscrow(address newVotingEscrow)
  external virtual {
    _authorizeUpdateVotingEscrow(msg.sender);
    _setVotingEscrow(newVotingEscrow);
  }

  function _setVotingEscrow(address newVotingEscrow)
  internal virtual {
    _votingEscrow = newVotingEscrow;
    emit VotingEscrowSet(newVotingEscrow);
  }
}
