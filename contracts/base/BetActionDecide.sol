// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionDecide} from "../interface/IBetActionDecide.sol";
import {IErrors} from "../interface/IErrors.sol";
import {IVotingEscrow} from "../interface/IVotingEscrow.sol";
import {AddressArrayLib} from "../lib/Address.sol";
import {MathLib} from "../lib/Math.sol";
import {Record} from "../lib/Record.sol";

abstract contract BetActionDecide is IBetActionDecide, IErrors {
  using MathLib for uint256;
  using AddressArrayLib for address[];

  address[] private _accounts;
  mapping(address => uint256) private _amounts;
  uint256 private _totalAmount;
  uint256 private _releasedOffset;
  bool private _released;
  bool private _confiscated;
  bool private _unfixed;

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
    IBet.Status status = IBet(bet()).statusUpdate();
    if (status < IBet.Status.DECIDING) revert DecidingPeriodHasNotStartedYet();
    if (status > IBet.Status.DECIDING) revert DecidingPeriodHasAlreadyEnded();

    address vote_ = vote();
    uint256 decidedAmount_ = _amounts[decider];
    if (decidedAmount_ > 0) {
      _amounts[decider] = 0;
      _totalAmount = _totalAmount.unsafeSub(decidedAmount_);
      _accounts.remove(decider);
      IVotingEscrow(vote_).unfix(decider, decidedAmount_);
    }

    if (amount > 0) {
      if (amount < voteMinValue()) revert InvalidAmount();
      IVotingEscrow(vote_).fix(decider, amount);
      _amounts[decider] = amount;
      _totalAmount = _totalAmount.unsafeAdd(amount);
      _accounts.push(decider);
    }

    emit Decided(decider, amount);
  }

  function decidedAmount()
  public view
  returns (uint256) {
    return _totalAmount;
  }

  function decidedAmount(address decider)
  public view
  returns (uint256) {
    return _amounts[decider];
  }

  function decidedRecords()
  public view
  returns (Record[] memory) {
    return decidedRecords(0, _accounts.length);
  }

  function decidedRecords(uint256 offset, uint256 limit)
  public view
  returns (Record[] memory) {
    address[] memory accounts = _accounts.slice(offset, limit);
    uint256 length = accounts.length;
    Record[] memory arr = new Record[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address account = accounts[i];
      arr[i] = Record(account, _amounts[account]);
    }
    return arr;
  }

  function decidedRecordCount()
  public view
  returns (uint256) {
    return _accounts.length;
  }

  function confiscateDecidedVotes()
  public
  onlyBet {
    confiscateDecidedVotes(0);
  }

  function confiscateDecidedVotes(uint256 limit)
  public
  onlyBet {
    if (_released || _unfixed) return;
    address bet_ = bet();
    if (IBet(bet_).status() <= IBet.Status.DECIDING) revert DecidingPeriodHasNotEndedYet();
    _confiscated = true;

    (uint256 start, uint256 end) = _getReleasedRangeOfDecidedRecords(limit);
    (address[] memory accounts, uint256[] memory amounts) = _getDecidedAccountsAndAmounts(start, end);
    IVotingEscrow(vote()).confiscateBatch(accounts, amounts, bet_);
  }

  function unfixDecidedVotes()
  public
  onlyBet {
    unfixDecidedVotes(0);
  }

  function unfixDecidedVotes(uint256 limit)
  public
  onlyBet {
    if (_released || _confiscated) return;
    if (IBet(bet()).status() <= IBet.Status.DECIDING) revert DecidingPeriodHasNotEndedYet();
    _unfixed = true;

    (uint256 start, uint256 end) = _getReleasedRangeOfDecidedRecords(limit);
    (address[] memory accounts, uint256[] memory amounts) = _getDecidedAccountsAndAmounts(start, end);
    IVotingEscrow(vote()).unfixBatch(accounts, amounts);
  }

  function _getDecidedAccountsAndAmounts(uint256 start, uint256 end)
  private view
  returns (address[] memory, uint256[] memory) {
    uint256 length = end.unsafeSub(start);
    address[] memory accounts = new address[](length);
    uint256[] memory amounts = new uint256[](length);
    for (uint256 i = start; i < end; i = i.unsafeInc()) {
      address account = _accounts[i];
      uint256 index = i.unsafeSub(start);
      accounts[index] = account;
      amounts[index] = _amounts[account];
    }
    return (accounts, amounts);
  }

  function _getReleasedRangeOfDecidedRecords(uint256 limit)
  private
  returns (uint256 start, uint256 end) {
    uint256 offset = _releasedOffset;
    bool isAll = offset == 0 && limit == 0;
    uint256 length = _accounts.length;
    if (isAll) {
      start = 0;
      end = length;
      _released = true;
    } else {
      start = offset;
      if (limit == 0) limit = length.unsafeSub(start);
      end = start.add(limit).min(length);
      if (end == length) {
        _released = true;
      } else {
        _releasedOffset = end;
      }
    }
  }

  function decidedVotesReleased()
  public view
  returns (bool) {
    return _released;
  }
}
