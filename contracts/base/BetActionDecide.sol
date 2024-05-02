// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionDecide} from "../interface/IBetActionDecide.sol";
import {IBetVotingEscrow} from "../interface/IBetVotingEscrow.sol";
import {IErrors} from "../interface/IErrors.sol";
import {MathLib} from "../lib/Math.sol";
import {Record, RecordArrayLib} from "../lib/Record.sol";

abstract contract BetActionDecide is IBetActionDecide, IErrors {
  using MathLib for uint256;
  using RecordArrayLib for Record[];

  Record[] private _decidedRecords;
  bool private _decidedVotesReleased;

  error DecidingPeriodHasNotStartedYet();
  error DecidingPeriodHasAlreadyEnded();
  error DecidingPeriodHasNotEndedYet();

  function bet()
  public view virtual
  returns (address);

  function vote()
  public view virtual
  returns (address);

  function voteMinValue()
  public view virtual
  returns (uint256) {
    return 0;
  }

  modifier onlyBet() virtual {
    if (msg.sender != bet()) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  modifier onlyVote() virtual {
    if (msg.sender != vote()) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function decide(uint256 amount)
  public virtual {
    _decide(msg.sender, amount);
  }

  function decide(address decider, uint256 amount)
  public virtual
  onlyVote {
    _decide(decider, amount);
  }

  function _decide(address decider, uint256 amount)
  internal {
    IBet.Status status = IBet(bet()).status();
    if (status < IBet.Status.DECIDING) revert DecidingPeriodHasNotStartedYet();
    if (status > IBet.Status.DECIDING) revert DecidingPeriodHasAlreadyEnded();

    IBetVotingEscrow vote_ = IBetVotingEscrow(vote());
    uint256 decidedAmount_ = _decidedRecords.remove(decider).amount;
    if (decidedAmount_ > 0) {
      vote_.unfix(decider, decidedAmount_);
    }

    if (amount > 0) {
      if (amount < voteMinValue()) revert InvalidAmount();
      vote_.fix(decider, amount);
      _decidedRecords.add(
        Record(decider, amount)
      );
    }

    emit Decided(decider, amount);
  }

  function decidedAmount()
  public view
  returns (uint256) {
    return _decidedRecords.sumAmount();
  }

  function decidedAmount(address decider)
  public view
  returns (uint256) {
    return _decidedRecords.find(decider).amount;
  }

  function decidedRecords()
  public view
  returns (Record[] memory) {
    return _decidedRecords;
  }

  function confiscateDecidedVotes()
  external
  onlyBet {
    if (_decidedVotesReleased) return;

    address bet_ = bet();
    IBet.Status status = IBet(bet_).status();
    if (status <= IBet.Status.DECIDING) revert DecidingPeriodHasNotEndedYet();

    _decidedVotesReleased = true;
    IBetVotingEscrow vote_ = IBetVotingEscrow(vote());
    uint256 length = _decidedRecords.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = _decidedRecords[i];
      vote_.confiscate(record.account, record.amount, bet_);
    }
  }

  function unfixDecidedVotes()
  external
  onlyBet {
    if (_decidedVotesReleased) return;

    IBet.Status status = IBet(bet()).status();
    if (status <= IBet.Status.DECIDING) revert DecidingPeriodHasNotEndedYet();

    _decidedVotesReleased = true;
    IBetVotingEscrow vote_ = IBetVotingEscrow(vote());
    uint256 length = _decidedRecords.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = _decidedRecords[i];
      vote_.unfix(record.account, record.amount);
    }
  }

  function decidedVotesReleased()
  external view
  returns (bool) {
    return _decidedVotesReleased;
  }
}
