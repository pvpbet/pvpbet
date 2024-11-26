// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionDispute} from "../interface/IBetActionDispute.sol";
import {IBetChip} from "../interface/IBetChip.sol";
import {IErrors} from "../interface/IErrors.sol";
import {AddressLib} from "../lib/Address.sol";
import {AddressArrayLib} from "../lib/AddressArray.sol";
import {MathLib} from "../lib/Math.sol";
import {Record} from "../lib/Record.sol";
import {TransferLib} from "../lib/Transfer.sol";

abstract contract BetActionDispute is IBetActionDispute, IErrors {
  using MathLib for uint256;
  using TransferLib for address;
  using AddressLib for address;
  using AddressArrayLib for address[];

  address[] private _accounts;
  mapping(address => uint256) private _amounts;
  uint256 private _totalAmount;
  uint256 private _releasedOffset;
  bool private _released;
  bool private _collected;
  bool private _refunded;

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
    address disputer = msg.sender;
    (uint256 payment, uint256 refund) = _dispute(disputer, amount);
    disputer.transfer(chip(), payment, refund);
  }

  function dispute(uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature)
  public virtual {
    address disputer = msg.sender;
    (uint256 payment, uint256 refund) = _dispute(disputer, amount);
    disputer.transfer(chip(), payment, refund, nonce, deadline, signature);
  }

  function dispute(address disputer, uint256 amount)
  public virtual
  onlyChip {
    (uint256 payment, uint256 refund) = _dispute(disputer, amount);
    disputer.transfer(chip(), payment, refund);
  }

  function _dispute(address disputer, uint256 amount)
  internal
  returns (uint256 payment, uint256 refund) {
    if (amount > 0 && amount < chipMinValue()) revert InvalidAmount();
    IBet.Status status = IBet(bet()).statusUpdate();
    if (status < IBet.Status.ANNOUNCEMENT) revert AnnouncementPeriodHasNotStartedYet();
    if (status > IBet.Status.ANNOUNCEMENT) revert AnnouncementPeriodHasAlreadyEnded();

    payment = amount;
    refund = _amounts[disputer];
    _amounts[disputer] = payment;

    if (payment > 0 && refund == 0) {
      _accounts.push(disputer);
    } else if (payment == 0 && refund > 0) {
      _accounts.remove(disputer);
    }

    if (payment > refund) {
      _totalAmount = _totalAmount.unsafeAdd(payment - refund);
    } else if (payment < refund) {
      _totalAmount = _totalAmount.unsafeSub(refund - payment);
    }

    emit Disputed(disputer, amount);
  }

  function disputedAmount()
  public view
  returns (uint256) {
    return _totalAmount;
  }

  function disputedAmount(address disputer)
  public view
  returns (uint256) {
    return _amounts[disputer];
  }

  function disputedRecords()
  public view
  returns (Record[] memory) {
    return disputedRecords(0, _accounts.length);
  }

  function disputedRecords(uint256 offset, uint256 limit)
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

  function disputedRecordCount()
  public view
  returns (uint256) {
    return _accounts.length;
  }

  function collectDisputedChips()
  public
  onlyBet {
    if (_released || _refunded) return;
    address bet_ = bet();
    if (IBet(bet_).status() <= IBet.Status.ARBITRATING) revert AnnouncementPeriodHasNotEndedYet();
    _collected = true;
    _released = true;

    if (bet_ != address(this)) {
      bet_.transferFromContract(chip(), type(uint256).max);
    }
  }

  function refundDisputedChips()
  public
  onlyBet {
    refundDisputedChips(0);
  }

  function refundDisputedChips(uint256 limit)
  public
  onlyBet {
    if (_released) return;
    if (IBet(bet()).status() <= IBet.Status.ARBITRATING) revert AnnouncementPeriodHasNotEndedYet();
    _refunded = true;

    address chip_ = chip();
    (uint256 start, uint256 end) = _getReleasedRangeOfDisputedRecords(limit);
    if (chip_.isBetChip()) {
      (address[] memory accounts, uint256[] memory amounts) = _getDisputedAccountsAndAmounts(start, end);
      IBetChip(chip_).transferBatch(accounts, amounts);
    } else {
      for (uint256 i = start; i < end; i = i.unsafeInc()) {
        address account = _accounts[i];
        account.transferFromContract(chip_, _amounts[account], true);
      }
    }
  }

  function _getDisputedAccountsAndAmounts(uint256 start, uint256 end)
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

  function _getReleasedRangeOfDisputedRecords(uint256 limit)
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

  function disputedChipsReleased()
  public view
  returns (bool) {
    return _released;
  }
}
