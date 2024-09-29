// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionWager} from "../interface/IBetActionWager.sol";
import {IErrors} from "../interface/IErrors.sol";
import {MathLib} from "../lib/Math.sol";
import {Record, RecordArrayLib} from "../lib/Record.sol";
import {TransferLib} from "../lib/Transfer.sol";

abstract contract BetActionWager is IBetActionWager, IErrors {
  using MathLib for uint256;
  using TransferLib for address;
  using RecordArrayLib for Record[];

  Record[] private _wageredRecords;
  uint256 private _wageredTotalAmount;
  uint256 private _releasedOffset;
  bool private _wageredChipsReleased;
  bool private _collected;
  bool private _refunded;

  error WageringPeriodHasAlreadyEnded();
  error WageringPeriodHasNotEndedYet();

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

  function wager(uint256 amount)
  public virtual {
    _wager(msg.sender, amount);
  }

  function wager(address player, uint256 amount)
  public virtual
  onlyChip {
    _wager(player, amount);
  }

  function _wager(address player, uint256 amount)
  internal {
    IBet.Status status = IBet(bet()).statusUpdate();
    if (status > IBet.Status.WAGERING) revert WageringPeriodHasAlreadyEnded();

    uint256 wageredAmount_ = _wageredRecords.remove(player).amount;
    if (wageredAmount_ > 0) {
      player.transferFromContract(chip(), wageredAmount_);
      _wageredTotalAmount = _wageredTotalAmount.unsafeSub(wageredAmount_);
    }

    if (amount > 0) {
      if (amount < chipMinValue()) revert InvalidAmount();
      player.transferToContract(chip(), amount);
      _wageredRecords.add(
        Record(player, amount)
      );
      _wageredTotalAmount = _wageredTotalAmount.unsafeAdd(amount);
    }

    emit Wagered(player, amount);
  }

  function wageredAmount()
  public view
  returns (uint256) {
    return _wageredTotalAmount;
  }

  function wageredAmount(address player)
  public view
  returns (uint256) {
    return _wageredRecords.find(player).amount;
  }

  function wageredRecords()
  public view
  returns (Record[] memory) {
    return _wageredRecords;
  }

  function wageredRecords(uint256 offset, uint256 limit)
  public view
  returns (Record[] memory) {
    return _wageredRecords.slice(offset, limit);
  }

  function wageredRecordCount()
  public view
  returns (uint256) {
    return _wageredRecords.length;
  }

  function collectWageredChips()
  external
  onlyBet {
    if (_wageredChipsReleased || _refunded) return;
    if (IBet(bet()).status() == IBet.Status.WAGERING) revert WageringPeriodHasNotEndedYet();
    _collected = true;
    _wageredChipsReleased = true;

    if (bet() != address(this)) {
      bet().transferFromContract(chip(), type(uint256).max);
    }
  }

  function refundWageredChips()
  external
  onlyBet {
    if (_wageredChipsReleased || _collected) return;
    if (IBet(bet()).status() == IBet.Status.WAGERING) revert WageringPeriodHasNotEndedYet();
    _refunded = true;
    _refundWageredChips(0);
  }

  function refundWageredChips(uint256 limit)
  external
  onlyBet {
    if (_wageredChipsReleased) return;
    if (IBet(bet()).status() == IBet.Status.WAGERING) revert WageringPeriodHasNotEndedYet();
    _refunded = true;
    _refundWageredChips(limit);
  }

  function _refundWageredChips(uint256 limit)
  private {
    uint256 offset = _releasedOffset;
    bool isAll = offset == 0 && limit == 0;
    if (isAll) {
      _wageredChipsReleased = true;
    } else {
      uint256 maxLength = _wageredRecords.length;
      if (limit == 0) limit = maxLength.sub(offset);
      _releasedOffset = offset.add(limit).min(maxLength);
      if (_releasedOffset == maxLength) {
        _wageredChipsReleased = true;
      }
    }

    Record[] memory records = isAll ? _wageredRecords : _wageredRecords.slice(offset, limit);
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = records[i];
      record.account.transferFromContract(chip(), record.amount, true);
    }
  }

  function wageredChipsReleased()
  public view
  returns (bool) {
    return _wageredChipsReleased;
  }
}
