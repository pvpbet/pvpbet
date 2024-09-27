// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Upgradeable} from "./base/Upgradeable.sol";
import {UseGovToken} from "./base/UseGovToken.sol";
import {UseVoteToken} from "./base/UseVoteToken.sol";
import {IBetVotingEscrow} from "./interface/IBetVotingEscrow.sol";
import {IErrors} from "./interface/IErrors.sol";
import {IGovTokenStaking} from "./interface/IGovTokenStaking.sol";
import {AddressLib} from "./lib/Address.sol";
import {MathLib} from "./lib/Math.sol";
import {TransferLib} from "./lib/Transfer.sol";
import {StakedRecord, StakedRecordLib, StakedRecordArrayLib, UnlockWaitingPeriod} from "./lib/StakedRecord.sol";
import {UnstakedRecord, UnstakedRecordLib, UnstakedRecordArrayLib} from "./lib/UnstakedRecord.sol";

contract GovTokenStaking is IGovTokenStaking, IErrors, Upgradeable, UseGovToken, UseVoteToken {
  function name()
  public pure override
  returns (string memory) {
    return "PVPBetGovTokenStaking";
  }

  function version()
  public pure override
  returns (string memory) {
    return "1.0.0";
  }

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
  error StakedAmountDeductionFailed();
  error StakedAmountInsufficientBalance(address account, UnlockWaitingPeriod, uint256 balance, uint256 value);

  StakedRecord[] private _stakedRecords;
  UnstakedRecord[] private _unstakedRecords;
  bool private _withdrawing;

  function initialize(address initialGovToken, address initialVoteToken)
  public
  initializer {
    initialize();
    _setGovToken(initialGovToken);
    _setVoteToken(initialVoteToken);
  }

  function _authorizeUpdateGovToken(address sender)
  internal view override(UseGovToken) onlyOwner {}

  function _authorizeUpdateVoteToken(address sender)
  internal view override(UseVoteToken) onlyOwner {}

  function stakeMinValue()
  public view
  returns (uint256) {
    return 10 ** govToken().decimals();
  }

  function stake(UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  external {
    if (unlockWaitingPeriod == UnlockWaitingPeriod.NONE) revert InvalidUnlockWaitingPeriod();
    if (amount < stakeMinValue()) revert InvalidAmount();

    address account = msg.sender;
    account.transferToContract(govToken(), amount);
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

  function extendUnlockWaitingPeriod(UnlockWaitingPeriod from, UnlockWaitingPeriod to)
  external {
    if (to == UnlockWaitingPeriod.NONE) revert InvalidUnlockWaitingPeriod();
    if (from >= to) revert InvalidUnlockWaitingPeriod();

    address account = msg.sender;
    (StakedRecord memory record,) = _getStakedRecord(account, from);

    record.removeFrom(_stakedRecords);
    emit Unstaked(account, from, record.amount);
    _stake(account, to, record.amount);
    emit Staked(account, to, record.amount);
  }

  function extendUnlockWaitingPeriod(UnlockWaitingPeriod from, UnlockWaitingPeriod to, uint256 amount)
  external {
    if (to == UnlockWaitingPeriod.NONE) revert InvalidUnlockWaitingPeriod();
    if (from >= to) revert InvalidUnlockWaitingPeriod();
    if (amount < stakeMinValue()) revert InvalidAmount();

    address account = msg.sender;
    (,uint256 index) = _getStakedRecord(account, from, amount);
    StakedRecord storage record = _stakedRecords[index.unsafeDec()];

    amount = amount.unsafeAdd(record.subAmount(amount, stakeMinValue(), _stakedRecords));
    emit Unstaked(account, from, amount);
    _stake(account, to, amount);
    emit Staked(account, to, amount);
  }

  function withdraw()
  external {
    if (_withdrawing) return;
    _withdrawing = true;

    uint256 blockTimestamp = block.timestamp;
    uint256 i = _unstakedRecords.length;
    while (i > 0) {
      i = i.unsafeDec();
      UnstakedRecord memory record = _unstakedRecords[i];
      if (blockTimestamp > record.unlockTime) {
        record.removeFrom(_unstakedRecords);
        record.account.transferFromContract(govToken(), record.amount);
        emit Withdrawn(record.account, record.unlockWaitingPeriod, record.amount);
      }
    }

    _withdrawing = false;
  }

  function deductStakedAmountAndTransfer(address account, uint256 amount, address custodian)
  public
  onlyVoteContract {
    uint256 remainingAmount = amount;
    remainingAmount = _deductStakedAmount(account, UnlockWaitingPeriod.WEEK, remainingAmount);
    if (remainingAmount > 0) remainingAmount = _deductStakedAmount(account, UnlockWaitingPeriod.WEEK12, remainingAmount);
    if (remainingAmount > 0) revert StakedAmountDeductionFailed();
    custodian.transferFromContract(govToken(), amount);
  }

  function batchDeductStakedAmountAndTransfer(address[] calldata accounts, uint256[] calldata amounts, address custodian)
  external
  onlyVoteContract {
    uint256 length = accounts.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      deductStakedAmountAndTransfer(accounts[i], amounts[i], custodian);
    }
  }

  function _deductStakedAmount(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private
  returns (uint256 remainingAmount) {
    (,uint256 index) = _stakedRecords.find(account, unlockWaitingPeriod);
    if (index > 0) {
      StakedRecord storage record = _stakedRecords[index.unsafeDec()];
      if (record.amount >= amount) {
        amount.unsafeAdd(record.subAmount(amount, stakeMinValue(), _stakedRecords));
        remainingAmount = 0;
      } else {
        record.removeFrom(_stakedRecords);
        remainingAmount = amount.unsafeSub(record.amount);
      }
    } else {
      remainingAmount = amount;
    }
  }

  function _mintStakingCertificate(address account, uint256 amount)
  private {
    IBetVotingEscrow(voteToken()).mint(account, amount);
  }

  function _burnStakingCertificate(address account, uint256 amount)
  private {
    IBetVotingEscrow(voteToken()).burn(account, amount);
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
    if (record.amount < amount) revert StakedAmountInsufficientBalance(record.account, record.unlockWaitingPeriod, record.amount, amount);
    return (record, index);
  }

  function isStaked(address account)
  external view
  returns (bool) {
    StakedRecord memory record;
    (record,) = _stakedRecords.find(account, UnlockWaitingPeriod.WEEK);
    if (record.account == account) return true;
    (record,) = _stakedRecords.find(account, UnlockWaitingPeriod.WEEK12);
    if (record.account == account) return true;
    return false;
  }

  function stakedAmount()
  external view
  returns (uint256) {
    return _stakedRecords.sumAmount();
  }

  function stakedAmount(UnlockWaitingPeriod unlockWaitingPeriod)
  external view
  returns (uint256) {
    return _stakedRecords.sumAmount(unlockWaitingPeriod);
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

  function stakedRecordCount(UnlockWaitingPeriod unlockWaitingPeriod)
  external view
  returns (uint256) {
    return _stakedRecords.find(unlockWaitingPeriod).length;
  }

  function stakedRecords()
  external view
  returns (StakedRecord[] memory) {
    return _stakedRecords;
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
