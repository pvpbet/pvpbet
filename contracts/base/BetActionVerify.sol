// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionVerify} from "../interface/IBetActionVerify.sol";
import {IErrors} from "../interface/IErrors.sol";
import {IVotingEscrow} from "../interface/IVotingEscrow.sol";
import {AddressArrayLib} from "../lib/Address.sol";
import {MathLib} from "../lib/Math.sol";
import {Record} from "../lib/Record.sol";

abstract contract BetActionVerify is IBetActionVerify, IErrors {
  using MathLib for uint256;
  using AddressArrayLib for address[];

  address[] private _accounts;
  mapping(address => uint256) private _amounts;
  uint256 private _totalAmount;
  uint256 private _releasedOffset;
  bool private _released;
  bool private _confiscated;
  bool private _unfixed;

  error VerifyingPeriodHasNotStartedYet();
  error VerifyingPeriodHasAlreadyEnded();
  error VerifyingPeriodHasNotEndedYet();

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

  function verify(uint256 amount)
  public virtual {
    address verifier = msg.sender;
    (uint256 payment, uint256 refund) = _verify(msg.sender, amount);
    _transfer(verifier, payment, refund);
  }

  function verify(address verifier, uint256 amount)
  public virtual
  onlyVote {
    (uint256 payment, uint256 refund) = _verify(verifier, amount);
    _transfer(verifier, payment, refund);
  }

  function _verify(address verifier, uint256 amount)
  internal
  returns (uint256 payment, uint256 refund) {
    if (amount > 0 && amount < voteMinValue()) revert InvalidAmount();
    IBet.Status status = IBet(bet()).statusUpdate();
    if (status < IBet.Status.VERIFYING) revert VerifyingPeriodHasNotStartedYet();
    if (status > IBet.Status.VERIFYING) revert VerifyingPeriodHasAlreadyEnded();

    payment = amount;
    refund = _amounts[verifier];
    _amounts[verifier] = payment;

    if (payment > 0 && refund == 0) {
      _accounts.push(verifier);
    } else if (payment == 0 && refund > 0) {
      _accounts.remove(verifier);
    }

    if (payment > refund) {
      _totalAmount = _totalAmount.unsafeAdd(payment - refund);
    } else if (payment < refund) {
      _totalAmount = _totalAmount.unsafeSub(refund - payment);
    }

    emit Verified(verifier, amount);
  }

  function _transfer(address owner, uint256 payment, uint256 refund)
  internal {
    if (payment > refund) {
      IVotingEscrow(vote()).fix(owner, payment - refund);
    } else if (payment < refund) {
      IVotingEscrow(vote()).unfix(owner, refund - payment);
    }
  }

  function verifiedAmount()
  public view
  returns (uint256) {
    return _totalAmount;
  }

  function verifiedAmount(address verifier)
  public view
  returns (uint256) {
    return _amounts[verifier];
  }

  function verifiedRecords()
  public view
  returns (Record[] memory) {
    return verifiedRecords(0, _accounts.length);
  }

  function verifiedRecords(uint256 offset, uint256 limit)
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

  function verifiedRecordCount()
  public view
  returns (uint256) {
    return _accounts.length;
  }

  function confiscateVerifiedVotes()
  public
  onlyBet {
    confiscateVerifiedVotes(0);
  }

  function confiscateVerifiedVotes(uint256 limit)
  public
  onlyBet {
    if (_released || _unfixed) return;
    address bet_ = bet();
    if (IBet(bet_).status() <= IBet.Status.VERIFYING) revert VerifyingPeriodHasNotEndedYet();
    _confiscated = true;

    (uint256 start, uint256 end) = _getReleasedRangeOfVerifiedRecords(limit);
    (address[] memory accounts, uint256[] memory amounts) = _getVerifiedAccountsAndAmounts(start, end);
    IVotingEscrow(vote()).confiscateBatch(accounts, amounts, bet_);
  }

  function unfixVerifiedVotes()
  public
  onlyBet {
    unfixVerifiedVotes(0);
  }

  function unfixVerifiedVotes(uint256 limit)
  public
  onlyBet {
    if (_released || _confiscated) return;
    if (IBet(bet()).status() <= IBet.Status.VERIFYING) revert VerifyingPeriodHasNotEndedYet();
    _unfixed = true;

    (uint256 start, uint256 end) = _getReleasedRangeOfVerifiedRecords(limit);
    (address[] memory accounts, uint256[] memory amounts) = _getVerifiedAccountsAndAmounts(start, end);
    IVotingEscrow(vote()).unfixBatch(accounts, amounts);
  }

  function _getVerifiedAccountsAndAmounts(uint256 start, uint256 end)
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

  function _getReleasedRangeOfVerifiedRecords(uint256 limit)
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

  function verifiedVotesReleased()
  public view
  returns (bool) {
    return _released;
  }
}
