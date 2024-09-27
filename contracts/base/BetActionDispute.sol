// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionDispute} from "../interface/IBetActionDispute.sol";
import {IErrors} from "../interface/IErrors.sol";
import {MathLib} from "../lib/Math.sol";
import {Record, RecordArrayLib} from "../lib/Record.sol";
import {TransferLib} from "../lib/Transfer.sol";

abstract contract BetActionDispute is IBetActionDispute, IErrors {
  using MathLib for uint256;
  using TransferLib for address;
  using RecordArrayLib for Record[];

  Record[] private _disputedRecords;
  uint256 private _disputedTotalAmount;
  bool private _disputedChipsReleased;

  error AnnouncementPeriodHasNotStartedYet();
  error AnnouncementPeriodHasAlreadyEnded();
  error AnnouncementPeriodHasNotEndedYet();

  function bet()
  public view virtual
  returns (address);

  function chip()
  public view virtual
  returns (address);

  function chipMinValue()
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

  modifier onlyChip() virtual {
    if (msg.sender != chip()) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function dispute(uint256 amount)
  public virtual {
    _dispute(msg.sender, amount);
  }

  function dispute(address disputer, uint256 amount)
  public virtual
  onlyChip {
    _dispute(disputer, amount);
  }

  function _dispute(address disputer, uint256 amount)
  internal {
    IBet bet_ = IBet(bet());
    IBet.Status status = bet_.status();
    if (status < IBet.Status.ANNOUNCEMENT) revert AnnouncementPeriodHasNotStartedYet();
    if (status > IBet.Status.ANNOUNCEMENT) revert AnnouncementPeriodHasAlreadyEnded();

    uint256 disputedAmount_ = _disputedRecords.remove(disputer).amount;
    if (disputedAmount_ > 0) {
      disputer.transferFromContract(chip(), disputedAmount_);
      _disputedTotalAmount = _disputedTotalAmount.sub(disputedAmount_);
    }

    if (amount > 0) {
      if (amount < chipMinValue()) revert InvalidAmount();
      disputer.transferToContract(chip(), amount);
      _disputedRecords.add(
        Record(disputer, amount)
      );
      _disputedTotalAmount = _disputedTotalAmount.add(amount);
    }

    bet_.statusUpdate();
    emit Disputed(disputer, amount);
  }

  function disputedAmount()
  public view
  returns (uint256) {
    return _disputedTotalAmount;
  }

  function disputedAmount(address disputer)
  public view
  returns (uint256) {
    return _disputedRecords.find(disputer).amount;
  }

  function disputedRecords()
  public view
  returns (Record[] memory) {
    return _disputedRecords;
  }

  function collectDisputedChips()
  external
  onlyBet {
    if (_disputedChipsReleased) return;

    if (IBet(bet()).status() <= IBet.Status.ARBITRATING) revert AnnouncementPeriodHasNotEndedYet();

    _disputedChipsReleased = true;
    if (bet() != address(this)) {
      bet().transferFromContract(chip(), type(uint256).max);
    }
  }

  function refundDisputedChips()
  external
  onlyBet {
    if (_disputedChipsReleased) return;

    if (IBet(bet()).status() <= IBet.Status.ARBITRATING) revert AnnouncementPeriodHasNotEndedYet();

    _disputedChipsReleased = true;
    uint256 length = _disputedRecords.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = _disputedRecords[i];
      record.account.transferFromContract(chip(), record.amount, true);
    }
  }

  function disputedChipsReleased()
  external view
  returns (bool) {
    return _disputedChipsReleased;
  }
}
