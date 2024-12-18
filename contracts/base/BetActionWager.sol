// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionWager} from "../interface/IBetActionWager.sol";
import {IBetChip} from "../interface/IBetChip.sol";
import {IErrors} from "../interface/IErrors.sol";
import {AddressLib} from "../lib/Address.sol";
import {AddressArrayLib} from "../lib/AddressArray.sol";
import {MathLib} from "../lib/Math.sol";
import {Record} from "../lib/Record.sol";
import {TransferLib} from "../lib/Transfer.sol";

abstract contract BetActionWager is IBetActionWager, IErrors {
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

  function proxy()
  public view virtual
  returns (address) {
    return 0x054548F8ce087Aa516ECE75320F929f75f8D7f25;
  }

  modifier onlyBet() virtual {
    if (msg.sender != bet()) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  modifier onlyProxy() virtual {
    if (
      msg.sender != chip()
      && msg.sender != 0x6A950D7EdC9608c209c49aCf939B2294fEf1f201
    ) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function wager(uint256 amount)
  public virtual {
    address player = msg.sender;
    (uint256 payment, uint256 refund) = _wager(player, amount);
    player.transfer(chip(), payment, refund);
  }

  function wager(uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature)
  public virtual {
    address player = msg.sender;
    (uint256 payment, uint256 refund) = _wager(player, amount);
    player.transfer(chip(), payment, refund, nonce, deadline, signature);
  }

  function wager(address player, uint256 amount)
  public virtual
  onlyProxy {
    (uint256 payment, uint256 refund) = _wager(player, amount);
    player.transfer(chip(), payment, refund);
  }

  function wager(address player, uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature)
  public virtual
  onlyProxy {
    (uint256 payment, uint256 refund) = _wager(player, amount);
    player.transfer(chip(), payment, refund, nonce, deadline, signature);
  }

  function _wager(address player, uint256 amount)
  internal
  returns (uint256 payment, uint256 refund) {
    if (amount > 0 && amount < chipMinValue()) revert InvalidAmount();
    IBet.Status status = IBet(bet()).statusUpdate();
    if (status > IBet.Status.WAGERING) revert WageringPeriodHasAlreadyEnded();

    payment = amount;
    refund = _amounts[player];
    _amounts[player] = payment;

    if (payment > 0 && refund == 0) {
      _accounts.push(player);
    } else if (payment == 0 && refund > 0) {
      _accounts.remove(player);
    }

    if (payment > refund) {
      _totalAmount = _totalAmount.unsafeAdd(payment - refund);
    } else if (payment < refund) {
      _totalAmount = _totalAmount.unsafeSub(refund - payment);
    }

    emit Wagered(player, amount);
  }

  function wageredAmount()
  public view
  returns (uint256) {
    return _totalAmount;
  }

  function wageredAmount(address player)
  public view
  returns (uint256) {
    return _amounts[player];
  }

  function wageredRecords()
  public view
  returns (Record[] memory) {
    return wageredRecords(0, _accounts.length);
  }

  function wageredRecords(uint256 offset, uint256 limit)
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

  function wageredRecordCount()
  public view
  returns (uint256) {
    return _accounts.length;
  }

  function collectWageredChips()
  public
  onlyBet {
    if (_released || _refunded) return;
    address bet_ = bet();
    if (IBet(bet_).status() == IBet.Status.WAGERING) revert WageringPeriodHasNotEndedYet();
    _collected = true;
    _released = true;

    if (bet_ != address(this)) {
      bet_.transferFromContract(chip(), type(uint256).max);
    }
  }

  function refundWageredChips()
  public
  onlyBet {
    refundWageredChips(0);
  }

  function refundWageredChips(uint256 limit)
  public
  onlyBet {
    if (_released) return;
    if (IBet(bet()).status() == IBet.Status.WAGERING) revert WageringPeriodHasNotEndedYet();
    _refunded = true;

    address chip_ = chip();
    (uint256 start, uint256 end) = _getReleasedRangeOfWageredRecords(limit);
    if (chip_.isBetChip()) {
      (address[] memory accounts, uint256[] memory amounts) = _getWageredAccountsAndAmounts(start, end);
      IBetChip(chip_).transferBatch(accounts, amounts);
    } else {
      for (uint256 i = start; i < end; i = i.unsafeInc()) {
        address account = _accounts[i];
        account.transferFromContract(chip_, _amounts[account], true);
      }
    }
  }

  function _getWageredAccountsAndAmounts(uint256 start, uint256 end)
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

  function _getReleasedRangeOfWageredRecords(uint256 limit)
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

  function wageredChipsReleased()
  public view
  returns (bool) {
    return _released;
  }
}
