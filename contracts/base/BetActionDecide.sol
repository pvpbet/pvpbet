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
  uint256 private _decidedTotalAmount;
  uint256 private _releasedOffset;
  bool private _decidedVotesPartialReleased;
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
    IBet bet_ = IBet(bet());
    IBet.Status status = bet_.status();
    if (status < IBet.Status.DECIDING) revert DecidingPeriodHasNotStartedYet();
    if (status > IBet.Status.DECIDING) revert DecidingPeriodHasAlreadyEnded();

    IBetVotingEscrow vote_ = IBetVotingEscrow(vote());
    uint256 decidedAmount_ = _decidedRecords.remove(decider).amount;
    if (decidedAmount_ > 0) {
      vote_.unfix(decider, decidedAmount_);
      _decidedTotalAmount = _decidedTotalAmount.unsafeSub(decidedAmount_);
    }

    if (amount > 0) {
      if (amount < voteMinValue()) revert InvalidAmount();
      vote_.fix(decider, amount);
      _decidedRecords.add(
        Record(decider, amount)
      );
      _decidedTotalAmount = _decidedTotalAmount.unsafeAdd(amount);
    }

    bet_.statusUpdate();
    emit Decided(decider, amount);
  }

  function decidedAmount()
  public view
  returns (uint256) {
    return _decidedTotalAmount;
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
    if (_decidedVotesReleased || _decidedVotesPartialReleased) return;
    (address[] memory accounts, uint256[] memory amounts) = _getAccountsAndAmounts(0);
    IBetVotingEscrow(vote()).confiscateBatch(accounts, amounts, bet());
  }

  function confiscateDecidedVotes(uint256 limit)
  external
  onlyBet {
    if (_decidedVotesReleased) return;
    (address[] memory accounts, uint256[] memory amounts) = _getAccountsAndAmounts(limit);
    IBetVotingEscrow(vote()).confiscateBatch(accounts, amounts, bet());
  }

  function unfixDecidedVotes()
  external
  onlyBet {
    if (_decidedVotesReleased || _decidedVotesPartialReleased) return;
    (address[] memory accounts, uint256[] memory amounts) = _getAccountsAndAmounts(0);
    IBetVotingEscrow(vote()).unfixBatch(accounts, amounts);
  }

  function unfixDecidedVotes(uint256 limit)
  external
  onlyBet {
    if (_decidedVotesReleased) return;
    (address[] memory accounts, uint256[] memory amounts) = _getAccountsAndAmounts(limit);
    IBetVotingEscrow(vote()).unfixBatch(accounts, amounts);
  }

  function _getAccountsAndAmounts(uint256 limit)
  private
  returns (address[] memory, uint256[] memory) {
    if (IBet(bet()).status() <= IBet.Status.DECIDING) revert DecidingPeriodHasNotEndedYet();

    uint256 offset = _releasedOffset;
    bool isAll = offset == 0 && limit == 0;
    uint256 maxLength = _decidedRecords.length;
    if (limit == 0) limit = maxLength.sub(offset);
    _releasedOffset = offset.add(limit).min(maxLength);
    if (_releasedOffset == maxLength) {
      _decidedVotesReleased = true;
    } else {
      _decidedVotesPartialReleased = true;
    }

    Record[] memory records = isAll ? _decidedRecords : _decidedRecords.slice(offset, limit);

    uint256 length = records.length;
    address[] memory accounts = new address[](length);
    uint256[] memory amounts = new uint256[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = records[i];
      accounts[i] = record.account;
      amounts[i] = record.amount;
    }

    return (accounts, amounts);
  }

  function decidedVotesReleased()
  public view
  returns (bool) {
    return _decidedVotesReleased;
  }
}
