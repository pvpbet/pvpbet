// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IErrors} from "../interface/IErrors.sol";
import {IStaking} from "../interface/IStaking.sol";
import {MathLib} from "../lib/Math.sol";
import {AddressLib} from "../lib/Address.sol";
import {TransferLib} from "../lib/Transfer.sol";
import {StakedRecord, StakedRecordLib, StakedRecordArrayLib, UnlockWaitingPeriod} from "../lib/StakedRecord.sol";
import {UnstakedRecord, UnstakedRecordLib, UnstakedRecordArrayLib} from "../lib/UnstakedRecord.sol";

abstract contract Staking is IStaking, IErrors {
  using MathLib for uint256;
  using AddressLib for address;
  using TransferLib for address;
  using StakedRecordLib for StakedRecord;
  using StakedRecordArrayLib for StakedRecord[];
  using UnstakedRecordLib for UnstakedRecord;
  using UnstakedRecordArrayLib for UnstakedRecord[];

  error CannotRestake();
  error InvalidUnlockWaitingPeriod();
  error NoStakedRecordFound();
  error NoUnstakedRecordFound();
  error StakeInsufficientBalance(address account, UnlockWaitingPeriod, uint256 balance, uint256 value);

  StakedRecord[] private _stakedRecords;
  UnstakedRecord[] private _unstakedRecords;
  bool private _withdrawing;

  function _mintStakingCertificate(address account, uint256 amount)
  internal virtual;

  function _burnStakingCertificate(address account, uint256 amount)
  internal virtual;

  function _unstakeAmountCheck(address account, uint256 amount)
  internal view virtual {}

  function govToken()
  public view virtual
  returns (address);

  function stakeMinValue()
  public view virtual
  returns (uint256) {
    return 10 ** govToken().decimals();
  }

  function __stakedRecords()
  internal view
  returns (StakedRecord[] storage) {
    return _stakedRecords;
  }

  function _getStakedRecord(address account, UnlockWaitingPeriod unlockWaitingPeriod)
  private view
  returns (StakedRecord memory, uint256) {
    (StakedRecord memory record, uint256 index) = _stakedRecords.find(account, unlockWaitingPeriod);
    if (index == 0) revert NoStakedRecordFound();
    return (record, index);
  }

  function _getStakedRecord(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private view
  returns (StakedRecord memory, uint256) {
    (StakedRecord memory record, uint256 index) = _stakedRecords.find(account, unlockWaitingPeriod);
    if (index == 0) revert NoStakedRecordFound();
    if (record.amount < amount) revert StakeInsufficientBalance(record.account, record.unlockWaitingPeriod, record.amount, amount);
    return (record, index);
  }

  function stake(UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  external {
    if (unlockWaitingPeriod == UnlockWaitingPeriod.NONE || unlockWaitingPeriod > type(UnlockWaitingPeriod).max) revert InvalidUnlockWaitingPeriod();
    if (amount < stakeMinValue()) revert InvalidAmount();

    address account = msg.sender;
    account.transferToSelf(govToken(), amount);
    _mintStakingCertificate(account, amount);
    _stake(account, unlockWaitingPeriod, amount);
    emit Staked(account, unlockWaitingPeriod, amount);
  }

  function _stake(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private {
    (,uint256 index) = _stakedRecords.find(account, unlockWaitingPeriod);
    if (index > 0) {
      _stakedRecords[index.unsafeDec()].addAmount(amount);
    } else {
      _stakedRecords.add(
        StakedRecord(account, unlockWaitingPeriod, amount)
      );
    }
  }

  function unstake(UnlockWaitingPeriod unlockWaitingPeriod)
  external {
    address account = msg.sender;
    (StakedRecord memory record,) = _getStakedRecord(account, unlockWaitingPeriod);
    uint256 amount = record.amount;

    record.removeFrom(_stakedRecords);
    _burnStakingCertificate(account, amount);
    _unstakedRecords.add(
      UnstakedRecord(
        account,
        unlockWaitingPeriod,
        amount,
        0,
        0
      )
    );
    emit Unstaked(account, unlockWaitingPeriod, amount);
  }

  function unstake(UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  external {
    if (amount < stakeMinValue()) revert InvalidAmount();

    address account = msg.sender;
    (,uint256 index) = _getStakedRecord(account, unlockWaitingPeriod, amount);
    _unstakeAmountCheck(account, amount);
    StakedRecord storage record = _stakedRecords[index.unsafeDec()];

    amount = amount.unsafeAdd(record.subAmount(amount, stakeMinValue(), _stakedRecords));
    _burnStakingCertificate(account, amount);
    _unstakedRecords.add(
      UnstakedRecord(
        account,
        unlockWaitingPeriod,
        amount,
        0,
        0
      )
    );
    emit Unstaked(account, unlockWaitingPeriod, amount);
  }

  function restake(uint256 index)
  external {
    if (index >= _unstakedRecords.length) revert NoUnstakedRecordFound();
    UnstakedRecord memory record = _unstakedRecords[index];
    address account = msg.sender;
    if (record.account != account) revert UnauthorizedAccess(account);
    if (block.timestamp > record.unlockTime) revert CannotRestake();

    record.removeFrom(_unstakedRecords);
    _mintStakingCertificate(record.account, record.amount);
    _stake(record.account, record.unlockWaitingPeriod, record.amount);
    emit Staked(record.account, record.unlockWaitingPeriod, record.amount);
  }

  function increaseUnlockWaitingPeriod()
  external {
    address account = msg.sender;
    (StakedRecord memory record,) = _getStakedRecord(account, UnlockWaitingPeriod.WEEK);

    record.removeFrom(_stakedRecords);
    emit Unstaked(account, UnlockWaitingPeriod.WEEK, record.amount);
    _stake(account, UnlockWaitingPeriod.WEEK12, record.amount);
    emit Staked(account, UnlockWaitingPeriod.WEEK12, record.amount);
  }

  function increaseUnlockWaitingPeriod(uint256 amount)
  external {
    if (amount < stakeMinValue()) revert InvalidAmount();

    address account = msg.sender;
    (,uint256 index) = _getStakedRecord(account, UnlockWaitingPeriod.WEEK, amount);
    StakedRecord storage record = _stakedRecords[index.unsafeDec()];

    amount = amount.unsafeAdd(record.subAmount(amount, stakeMinValue(), _stakedRecords));
    emit Unstaked(account, UnlockWaitingPeriod.WEEK, amount);
    _stake(account, UnlockWaitingPeriod.WEEK12, amount);
    emit Staked(account, UnlockWaitingPeriod.WEEK12, amount);
  }

  function withdraw()
  external {
    if (_withdrawing) return;
    _withdrawing = true;

    uint256 blockTimestamp = block.timestamp;
    uint256 length = _unstakedRecords.length;
    for (uint256 i = length; i > 0; i = i.unsafeDec()) {
      UnstakedRecord memory record = _unstakedRecords[i.unsafeDec()];
      if (blockTimestamp > record.unlockTime) {
        record.removeFrom(_unstakedRecords);
        record.account.receiveFromSelf(govToken(), record.amount);
        emit Withdrawn(record.account, record.unlockWaitingPeriod, record.amount);
      }
    }

    _withdrawing = false;
  }

  function stakedAmount()
  external view
  returns (uint256) {
    return _stakedRecords.sumAmount();
  }

  function stakedAmount(address account)
  external view
  returns (uint256) {
    (StakedRecord memory a,) = _stakedRecords.find(account, UnlockWaitingPeriod.WEEK);
    (StakedRecord memory b,) = _stakedRecords.find(account, UnlockWaitingPeriod.WEEK12);
    return a.amount.unsafeAdd(b.amount);
  }

  function stakedAmount(address account, UnlockWaitingPeriod unlockWaitingPeriod)
  external view
  returns (uint256) {
    (StakedRecord memory record,) = _stakedRecords.find(account, unlockWaitingPeriod);
    return record.amount;
  }

  function stakedWeight()
  external view
  returns (uint256) {
    return _stakedRecords.sumWeight();
  }

  function stakedWeight(address account)
  external view
  returns (uint256) {
    (StakedRecord memory a,) = _stakedRecords.find(account, UnlockWaitingPeriod.WEEK);
    (StakedRecord memory b,) = _stakedRecords.find(account, UnlockWaitingPeriod.WEEK12);
    return a.getWeight().unsafeAdd(b.getWeight());
  }

  function stakedRecord(address account, UnlockWaitingPeriod unlockWaitingPeriod)
  external view
  returns (StakedRecord memory) {
    (StakedRecord memory record,) = _stakedRecords.find(account, unlockWaitingPeriod);
    return record;
  }

  function stakedRecordCount()
  external view
  returns (uint256) {
    return _stakedRecords.length;
  }

  function unstakedRecords(address account)
  external view
  returns (UnstakedRecord[] memory) {
    return _unstakedRecords.find(account);
  }

  function unstakedRecords(address account, UnlockWaitingPeriod unlockWaitingPeriod)
  external view
  returns (UnstakedRecord[] memory) {
    return _unstakedRecords.find(account, unlockWaitingPeriod);
  }
}
