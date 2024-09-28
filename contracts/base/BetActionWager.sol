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
  bool private _wageredChipsPartialReleased;
  bool private _wageredChipsReleased;

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
    IBet bet_ = IBet(bet());
    IBet.Status status = bet_.status();
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

    bet_.statusUpdate();
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

  function collectWageredChips()
  external
  onlyBet {
    if (_wageredChipsReleased || _wageredChipsPartialReleased) return;
    if (IBet(bet()).status() == IBet.Status.WAGERING) revert WageringPeriodHasNotEndedYet();
    _wageredChipsReleased = true;

    if (bet() != address(this)) {
      bet().transferFromContract(chip(), type(uint256).max);
    }
  }

  function refundWageredChips()
  external
  onlyBet {
    if (_wageredChipsReleased || _wageredChipsPartialReleased) return;
    if (IBet(bet()).status() == IBet.Status.WAGERING) revert WageringPeriodHasNotEndedYet();
    _wageredChipsReleased = true;

    uint256 length = _wageredRecords.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = _wageredRecords[i];
      record.account.transferFromContract(chip(), record.amount, true);
    }
  }

  function refundWageredChips(uint256 limit)
  external
  onlyBet {
    if (_wageredChipsReleased) return;
    if (IBet(bet()).status() == IBet.Status.WAGERING) revert WageringPeriodHasNotEndedYet();

    uint256 offset = _releasedOffset;
    uint256 maxLength = _wageredRecords.length;
    if (limit == 0) limit = maxLength.sub(offset);
    _releasedOffset = offset.add(limit).min(maxLength);
    if (_releasedOffset == maxLength) {
      _wageredChipsReleased = true;
    } else {
      _wageredChipsPartialReleased = true;
    }

    Record[] memory records = _wageredRecords.slice(offset, limit);
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
