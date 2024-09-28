// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BetActionArbitrate} from "./base/BetActionArbitrate.sol";
import {BetActionDispute} from "./base/BetActionDispute.sol";
import {IAccountLevel} from "./interface/IAccountLevel.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetActionArbitrate} from "./interface/IBetActionArbitrate.sol";
import {IBetActionDecide} from "./interface/IBetActionDecide.sol";
import {IBetActionWager} from "./interface/IBetActionWager.sol";
import {IBetManager} from "./interface/IBetManager.sol";
import {IBetOptionFactory} from "./interface/IBetOptionFactory.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {IRewardDistributable} from "./interface/IRewardDistributable.sol";
import {IUseGovToken} from "./interface/IUseGovToken.sol";
import {AddressLib} from "./lib/Address.sol";
import {MathLib} from "./lib/Math.sol";
import {Record, RecordArrayLib} from "./lib/Record.sol";
import {TransferLib} from "./lib/Transfer.sol";

contract Bet is IBet, Initializable, IMetadata, BetActionArbitrate, BetActionDispute {
  function name()
  public pure
  returns (string memory) {
    return "PVPBet";
  }

  function version()
  public view
  returns (string memory) {
    return _version;
  }

  using MathLib for uint256;
  using AddressLib for address;
  using TransferLib for address;
  using RecordArrayLib for Record[];

  error InvalidChip();
  error BetHasNotEndedYet();
  error BetHasBeenReleased();

  string private _version;
  BetConfig private _config;
  BetDetails private _details;
  address[] private _options;
  Status private _status;

  address private _creator;
  address private _chip;
  address private _vote;
  address private _betManager;
  address private _govToken;
  address private _unconfirmedWinningOption;
  address private _confirmedWinningOption;
  uint256 private _wageringPeriodDeadline;
  uint256 private _decidingPeriodDeadline;
  uint256 private _arbitratingPeriodStartTime;

  uint256 private _chipPerQuantity;
  uint256 private _votePerQuantity;
  uint256 private _minWageredTotalAmount;
  uint256 private _minDecidedTotalAmount;
  uint256 private _minArbitratedTotalAmount;

  uint256 private _releasedOffset;
  bool private _released;

  function initialize(
    string memory version_,
    BetConfig memory config_,
    BetDetails memory details_,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration,
    address creator_,
    address chip_,
    address vote_,
    address betManager,
    address betOptionFactory
  )
  public
  initializer {
    _version = version_;
    _config = config_;
    _details = details_;
    _wageringPeriodDeadline = block.timestamp.unsafeAdd(wageringPeriodDuration);
    _decidingPeriodDeadline = _wageringPeriodDeadline.unsafeAdd(decidingPeriodDuration);
    _creator = creator_;
    _chip = chip_;
    _vote = vote_;
    _betManager = betManager;
    _govToken = IUseGovToken(betManager).govToken();

    unchecked {
      _chipPerQuantity = 10 ** chip_.decimals();
      _votePerQuantity = 10 ** vote_.decimals();
      if (chip_ == address(0)) {
        _minWageredTotalAmount = config_.minWageredTotalAmountETH;
      } else {
        _minWageredTotalAmount = config_.minWageredTotalQuantityERC20.unsafeMul(_chipPerQuantity);
      }
      _minDecidedTotalAmount = config_.minDecidedTotalQuantity.unsafeMul(_votePerQuantity);
      _minArbitratedTotalAmount = config_.minArbitratedTotalQuantity.unsafeMul(_votePerQuantity);
    }

    _createBetOptions(details_, betOptionFactory);
  }

  function _createBetOptions(BetDetails memory details_, address betOptionFactory)
  private {
    IBetOptionFactory factory = IBetOptionFactory(betOptionFactory);
    uint256 length = details_.options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      _options.push(
        factory.createBetOption(
          details_.options[i],
          address(this),
          _chip,
          _vote,
          _chipPerQuantity,
          _votePerQuantity
        )
      );
    }
  }

  function isBet()
  external pure
  returns (bool) {
    return true;
  }

  function config()
  external view
  returns (BetConfig memory) {
    return _config;
  }

  function details()
  external view
  returns (BetDetails memory) {
    return _details;
  }

  function options()
  external view
  returns (address[] memory) {
    return _options;
  }

  function wageringPeriodDeadline()
  external view
  returns (uint256) {
    return _wageringPeriodDeadline;
  }

  function decidingPeriodDeadline()
  external view
  returns (uint256) {
    return _decidingPeriodDeadline;
  }

  function arbitratingPeriodStartTime()
  external view
  returns (uint256) {
    return _arbitratingPeriodStartTime;
  }

  function unconfirmedWinningOption()
  external view
  returns (address) {
    (,address unconfirmedWinningOption_,) = _getState();
    return unconfirmedWinningOption_;
  }

  function confirmedWinningOption()
  external view
  returns (address) {
    (,,address confirmedWinningOption_) = _getState();
    return confirmedWinningOption_;
  }

  function bet()
  public view override(BetActionArbitrate, BetActionDispute)
  returns (address) {
    return address(this);
  }

  function creator()
  external view
  returns (address) {
    return _creator;
  }

  function chip()
  public view override(IBet, BetActionDispute)
  returns (address) {
    return _chip;
  }

  function vote()
  public view override(IBet, BetActionArbitrate)
  returns (address) {
    return _vote;
  }

  function chipMinValue()
  public view override(IBet, BetActionDispute)
  returns (uint256) {
    if (_chip == address(0)) {
      return 0.001 ether;
    } else {
      return _chipPerQuantity;
    }
  }

  function voteMinValue()
  public view override(IBet, BetActionArbitrate)
  returns (uint256) {
    return _votePerQuantity;
  }

  function minWageredTotalAmount()
  public view
  returns (uint256) {
    return _minWageredTotalAmount;
  }

  function minDecidedTotalAmount()
  public view
  returns (uint256) {
    return _minDecidedTotalAmount;
  }

  function minDisputedTotalAmount()
  public view
  returns (uint256) {
    return wageredTotalAmount().mulDiv(_config.confirmDisputeAmountRatio, 100);
  }

  function minArbitratedTotalAmount()
  public view
  returns (uint256) {
    return _minArbitratedTotalAmount;
  }

  function wageredTotalAmount()
  public view
  returns (uint256) {
    uint256 total = 0;
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      total = total.unsafeAdd(IBetActionWager(_options[i]).wageredAmount());
    }
    return total;
  }

  function decidedTotalAmount()
  public view
  returns (uint256) {
    uint256 total = 0;
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      total = total.unsafeAdd(IBetActionDecide(_options[i]).decidedAmount());
    }
    return total;
  }

  function disputedTotalAmount()
  public view
  returns (uint256) {
    return disputedAmount();
  }

  function arbitratedTotalAmount()
  public view
  returns (uint256) {
    uint256 total = arbitratedAmount();
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      total = total.unsafeAdd(IBetActionArbitrate(_options[i]).arbitratedAmount());
    }
    return total;
  }

  function status()
  public view
  returns (Status) {
    (Status status_,,) = _getState();
    return status_;
  }

  function statusUpdate()
  external
  returns (Status) {
    (Status status_, address unconfirmedWinningOption_, address confirmedWinningOption_) = _getState();
    _status = status_;
    _unconfirmedWinningOption = unconfirmedWinningOption_;
    _confirmedWinningOption = confirmedWinningOption_;
    return status_;
  }

  function _getState()
  private view
  returns (Status status_, address unconfirmedWinningOption_, address confirmedWinningOption_) {
    status_ = _status;
    unconfirmedWinningOption_ = _unconfirmedWinningOption;
    confirmedWinningOption_ = _confirmedWinningOption;

    if (status_ == Status.WAGERING && block.timestamp > _wageringPeriodDeadline) {
      if (_isValidWager()) {
        status_ = Status.DECIDING;
      } else {
        status_ = Status.CANCELLED;
      }
    }

    if (status_ == Status.DECIDING && block.timestamp > _decidingPeriodDeadline) {
      unconfirmedWinningOption_ = _getDecidedWinningOption();
      if (unconfirmedWinningOption_ != address(0)) {
        status_ = Status.ANNOUNCEMENT;
      } else {
        status_ = Status.CANCELLED;
      }
    }

    if (status_ == Status.ANNOUNCEMENT) {
      if (_arbitratingPeriodStartTime > 0) {
        status_ = Status.ARBITRATING;
      } else if (block.timestamp > _decidingPeriodDeadline.unsafeAdd(_config.announcementPeriodDuration)) {
        confirmedWinningOption_ = unconfirmedWinningOption_;
        status_ = Status.CONFIRMED;
      }
    }

    if (status_ == Status.ARBITRATING && block.timestamp > _arbitratingPeriodStartTime.unsafeAdd(_config.arbitratingPeriodDuration)) {
      confirmedWinningOption_ = _getArbitratedWinningOption();
      if (confirmedWinningOption_ != address(0)) {
        status_ = Status.CONFIRMED;
      } else {
        status_ = Status.CANCELLED;
      }
    }

    return (status_, unconfirmedWinningOption_, confirmedWinningOption_);
  }

  function statusDeadline()
  external view
  returns (uint256) {
    Status status_ = status();
    if (status_ == Status.WAGERING) {
      return _wageringPeriodDeadline;
    } else if (status_ == Status.DECIDING) {
      return _decidingPeriodDeadline;
    } else if (status_ == Status.ANNOUNCEMENT) {
      return _decidingPeriodDeadline.unsafeAdd(_config.announcementPeriodDuration);
    } else if (status_ == Status.ARBITRATING) {
      return _arbitratingPeriodStartTime.unsafeAdd(_config.arbitratingPeriodDuration);
    } else {
      return 0;
    }
  }

  function dispute(uint256 amount)
  public override(BetActionDispute) {
    super.dispute(amount);
    if (_isValidDispute()) {
      _arbitratingPeriodStartTime = block.timestamp;
    }
  }

  function dispute(address disputer, uint256 amount)
  public override(BetActionDispute) {
    super.dispute(disputer, amount);
    if (_isValidDispute()) {
      _arbitratingPeriodStartTime = block.timestamp;
    }
  }

  function _isValidWager()
  private view
  returns (bool) {
    uint256 total = 0;
    uint256 length = _options.length;
    uint256[] memory optionAmounts = new uint256[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      optionAmounts[i] = IBetActionWager(_options[i]).wageredAmount();
      total = total.unsafeAdd(optionAmounts[i]);
    }

    if (total < _minWageredTotalAmount) {
      return false;
    }

    uint256 singleOptionMaxAmount = total.mulDiv(_config.singleOptionMaxAmountRatio, 100);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (optionAmounts[i] > singleOptionMaxAmount) {
        return false;
      }
    }

    return true;
  }

  function _isValidDispute()
  private view
  returns (bool) {
    return disputedAmount() >= minDisputedTotalAmount();
  }

  function _getDecidedWinningOption()
  private view
  returns (address) {
    address winningOption = address(0);
    uint256 max = 0;
    uint256 total = 0;
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      uint256 decidedAmount_ = IBetActionDecide(option).decidedAmount();
      total = total.unsafeAdd(decidedAmount_);
      if (decidedAmount_ > max) {
        max = decidedAmount_;
        winningOption = option;
      } else if (decidedAmount_ == max && winningOption != address(0)) {
        winningOption = address(0);
      }
    }
    if (total < _minDecidedTotalAmount) return address(0);
    return winningOption;
  }

  function _getArbitratedWinningOption()
  private view
  returns (address) {
    if (_arbitratingPeriodStartTime == 0) return address(0);
    address winningOption = address(0);
    uint256 max = arbitratedAmount();
    uint256 total = max;
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      uint256 arbitratedAmount_ = IBetActionArbitrate(option).arbitratedAmount();
      total = total.unsafeAdd(arbitratedAmount_);
      if (arbitratedAmount_ > max) {
        max = arbitratedAmount_;
        winningOption = option;
      } else if (arbitratedAmount_ == max && winningOption != address(0)) {
        winningOption = address(0);
      }
    }
    if (total < _minArbitratedTotalAmount) return address(0);
    return winningOption;
  }

  function release()
  public {
    release(0);
  }

  function release(uint256 limit)
  public {
    if (_released) revert BetHasBeenReleased();

    (Status status_, address unconfirmedWinningOption_, address confirmedWinningOption_) = _getState();
    if (status_ != Status.CONFIRMED && status_ != Status.CANCELLED) revert BetHasNotEndedYet();

    _unconfirmedWinningOption = unconfirmedWinningOption_;
    _confirmedWinningOption = confirmedWinningOption_;

    uint256 offset = _releasedOffset;
    bool isUnfinished;

    if (limit > 0) {
      _status = status_;
      _releasedOffset = _releasedOffset.add(limit);
    } else {
      _released = true;
      _status = Status.CLOSED;
    }

    if (status_ == Status.CONFIRMED) {
      if (_arbitratingPeriodStartTime > 0) {
        // Dispute occurred
        if (_confirmedWinningOption == _unconfirmedWinningOption) {
          if (_penalizeDisputer(offset, limit)) isUnfinished = true;
        } else {
          if (_penalizeDecider(offset, limit)) isUnfinished = true;
        }
      }

      if (_distribute(offset, limit)) isUnfinished = true;
    }

    if (_refund(offset, limit)) isUnfinished = true;

    if (!_released && !isUnfinished) {
      _released = true;
      _status = Status.CLOSED;
    }

    if (_released) {
      _destroy();
      if (msg.sender != _betManager) {
        IBetManager(_betManager).close();
      }
    }
  }

  function maxReleaseCount()
  external view
  returns (uint256) {
    uint256 maxReleaseCount_;

    (Status status_, address unconfirmedWinningOption_, address confirmedWinningOption_) = _getState();
    if (status_ < Status.CONFIRMED) return maxReleaseCount_;

    uint256 count;

    if (status_ == Status.CONFIRMED) {
      if (_arbitratingPeriodStartTime > 0) {
        // Dispute occurred
        if (confirmedWinningOption_ == unconfirmedWinningOption_) {
          count = IBetActionArbitrate(confirmedWinningOption_).arbitratedRecordCount();
          if (maxReleaseCount_ < count) maxReleaseCount_ = count;
        } else {
          count = IBetActionDecide(unconfirmedWinningOption_).decidedRecordCount()
            .unsafeAdd(IBetActionArbitrate(confirmedWinningOption_).arbitratedRecordCount());
          if (maxReleaseCount_ < count) maxReleaseCount_ = count;
        }
      }

      count = IBetActionDecide(confirmedWinningOption_).decidedRecordCount();
      if (maxReleaseCount_ < count) maxReleaseCount_ = count;
      count = IBetActionWager(confirmedWinningOption_).wageredRecordCount();
      if (maxReleaseCount_ < count) maxReleaseCount_ = count;
    }

    count = disputedRecordCount();
    if (maxReleaseCount_ < count) maxReleaseCount_ = count;

    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      count = IBetActionDecide(option).decidedRecordCount();
      if (maxReleaseCount_ < count) maxReleaseCount_ = count;
      count = IBetActionWager(option).wageredRecordCount();
      if (maxReleaseCount_ < count) maxReleaseCount_ = count;
    }

    return maxReleaseCount_;
  }

  function releasedOffset()
  external view
  returns (uint256) {
    return _releasedOffset;
  }

  function released()
  external view
  returns (bool) {
    return _released;
  }

  function _penalizeDisputer(uint256 offset, uint256 limit)
  private
  returns (bool) {
    bool isAll = offset == 0 && limit == 0;
    bool isUnfinished;

    IBetActionArbitrate actionArbitrate = IBetActionArbitrate(_confirmedWinningOption);
    uint256 length = actionArbitrate.arbitratedRecordCount();
    if (offset < length) {
      Record[] memory records = isAll
        ? actionArbitrate.arbitratedRecords()
        : actionArbitrate.arbitratedRecords().slice(offset, limit > 0 ? limit : length.unsafeSub(offset));

      if (offset == 0) this.collectDisputedChips();
      records.distribute(
        _chip,
        disputedAmount(),
        actionArbitrate.arbitratedAmount()
      );

      if (limit > 0 && _releasedOffset < length) isUnfinished = true;
    }

    return isUnfinished;
  }

  function _penalizeDecider(uint256 offset, uint256 limit)
  private
  returns (bool) {
    bool isAll = offset == 0 && limit == 0;
    bool isUnfinished;

    IBetActionDecide actionDecide = IBetActionDecide(_unconfirmedWinningOption);
    uint256 length = actionDecide.decidedRecordCount();
    if (offset < length) {
      Record[] memory records = isAll
        ? actionDecide.decidedRecords()
        : actionDecide.decidedRecords().slice(offset, limit > 0 ? limit : length.unsafeSub(offset));

      actionDecide.confiscateDecidedVotes(limit);
      _deciderLevelDown(records);

      if (limit > 0 && _releasedOffset < length) isUnfinished = true;
    }

    if (isAll || !isUnfinished) {
      if (limit == 0 || _releasedOffset > length) {
        if (_distributeConfiscatedAmount(actionDecide.decidedAmount(), length, offset, limit)) {
          isUnfinished = true;
        }
      } else {
        isUnfinished = true;
      }
    }

    return isUnfinished;
  }

  function _distributeConfiscatedAmount(uint256 confiscatedAmount, uint256 start, uint256 offset, uint256 limit)
  private
  returns (bool) {
    bool isAll = offset == 0 && limit == 0;
    bool isUnfinished;

    if (isAll || limit == 0 || _releasedOffset > start) {
      uint256 relativeReleasedOffset;
      if (_releasedOffset > start) {
        relativeReleasedOffset = _releasedOffset.unsafeSub(start);
        if (relativeReleasedOffset < limit) {
          offset = 0;
          limit = relativeReleasedOffset;
        } else {
          offset = relativeReleasedOffset.unsafeSub(limit);
        }
      }

      IBetActionArbitrate actionArbitrate = IBetActionArbitrate(_confirmedWinningOption);
      uint256 length = actionArbitrate.arbitratedRecordCount();
      if (offset < length) {
        Record[] memory records = isAll
          ? actionArbitrate.arbitratedRecords()
          : actionArbitrate.arbitratedRecords().slice(offset, limit > 0 ? limit : length.unsafeSub(offset));

        records.distribute(
          _govToken,
          confiscatedAmount,
          actionArbitrate.arbitratedAmount()
        );

        if (limit > 0 && relativeReleasedOffset < length) isUnfinished = true;
      }
    } else {
      isUnfinished = true;
    }

    return isUnfinished;
  }

  function _collectWageredChips()
  private
  returns (uint256) {
    uint256 total = 0;
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      IBetActionWager actionWager = IBetActionWager(_options[i]);
      actionWager.collectWageredChips();
      total = total.unsafeAdd(actionWager.wageredAmount());
    }
    return total;
  }

  function _distribute(uint256 offset, uint256 limit)
  private
  returns (bool) {
    bool isUnfinished;

    uint256 total = offset == 0 ? _collectWageredChips() : wageredTotalAmount();

    uint256 protocolReward = total.mulDiv(_config.protocolRewardRatio, 100);
    uint256 creatorReward = total.mulDiv(_config.creatorRewardRatio, 100);
    uint256 deciderReward = total.mulDiv(_config.deciderRewardRatio, 100);
    uint256 winnerReward = total.unsafeSub(protocolReward).unsafeSub(creatorReward).unsafeSub(deciderReward);

    if (offset == 0) _creator.transferFromContract(_chip, creatorReward, true);

    bool isUnfinished_;
    uint256 remainingAmount_;
    (isUnfinished_, remainingAmount_) = _distributeDeciderReward(deciderReward, offset, limit);
    if (isUnfinished_) isUnfinished = true;
    if (remainingAmount_ > 0) {
      protocolReward = protocolReward.unsafeAdd(remainingAmount_);
    }

    (isUnfinished_, remainingAmount_) = _distributeWinnerReward(winnerReward, offset, limit);
    if (isUnfinished_) isUnfinished = true;
    if (remainingAmount_ > 0) {
      protocolReward = protocolReward.unsafeAdd(remainingAmount_);
    }

    if (offset == 0) _distributeProtocolReward(protocolReward);

    return isUnfinished;
  }

  function _distributeDeciderReward(uint256 amount, uint256 offset, uint256 limit)
  private
  returns (bool, uint256) {
    bool isAll = offset == 0 && limit == 0;
    bool isUnfinished;

    IBetActionDecide actionDecide = IBetActionDecide(_confirmedWinningOption);
    uint256 length = actionDecide.decidedRecordCount();
    if (offset < length) {
      Record[] memory records = isAll
        ? actionDecide.decidedRecords()
        : actionDecide.decidedRecords().slice(offset, limit > 0 ? limit : length.unsafeSub(offset));

      records.distribute(_chip, amount, actionDecide.decidedAmount());
      _deciderLevelUp(records);

      if (limit > 0 && _releasedOffset < length) isUnfinished = true;
      amount = 0;
    }

    return (isUnfinished, amount);
  }

  function _distributeWinnerReward(uint256 amount, uint256 offset, uint256 limit)
  private
  returns (bool, uint256) {
    bool isAll = offset == 0 && limit == 0;
    bool isUnfinished;

    IBetActionWager actionWager = IBetActionWager(_confirmedWinningOption);
    uint256 length = actionWager.wageredRecordCount();
    if (offset < length) {
      Record[] memory records = isAll
        ? actionWager.wageredRecords()
        : actionWager.wageredRecords().slice(offset, limit > 0 ? limit : length.unsafeSub(offset));
      records.distribute(_chip, amount, actionWager.wageredAmount());

      if (limit > 0 && _releasedOffset < length) isUnfinished = true;
      amount = 0;
    }

    return (isUnfinished, amount);
  }

  function _distributeProtocolReward(uint256 amount)
  private {
    if (_chip == address(0)) {
      _vote.functionCallWithValue(
        abi.encodeWithSignature("distribute()"),
        amount
      );
    } else {
      IERC20(_chip).approve(_vote, amount);
      IRewardDistributable(_vote).distribute(_chip, amount);
    }
  }

  function _refund(uint256 offset, uint256 limit)
  private
  returns (bool) {
    bool isAll = offset == 0 && limit == 0;
    bool isUnfinished;
    if (isAll) {
      this.refundDisputedChips();
    } else {
      this.refundDisputedChips(limit);
      if (!disputedChipsReleased()) isUnfinished = true;
    }

    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      IBetActionDecide actionDecide = IBetActionDecide(option);
      IBetActionWager actionWager = IBetActionWager(option);
      if (isAll) {
        actionDecide.unfixDecidedVotes();
        actionWager.refundWageredChips();
      } else {
        actionDecide.unfixDecidedVotes(limit);
        actionWager.refundWageredChips(limit);
        if (!actionDecide.decidedVotesReleased() || !actionWager.wageredChipsReleased()) {
          isUnfinished = true;
        }
      }
    }

    return isUnfinished;
  }

  function _deciderLevelUp(Record[] memory records)
  private {
    uint256 length = records.length;
    address[] memory accounts = new address[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      accounts[i] = records[i].account;
    }
    IAccountLevel(_vote).levelUpBatch(accounts);
  }

  function _deciderLevelDown(Record[] memory records)
  private {
    uint256 length = records.length;
    address[] memory accounts = new address[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      accounts[i] = records[i].account;
    }
    IAccountLevel(_vote).levelDownBatch(accounts);
  }

  function _destroy()
  private {
    // Recycle funds from failed transfers.
    _betManager.transferFromContract(_chip, type(uint256).max, true);
  }

  receive() external payable {
    Status status_ = status();
    if (status_ >= Status.CONFIRMED) {
      if (msg.sender.isBetOption()) return;
      if (status_ == Status.CLOSED) revert CannotReceive();
      else if (status_ == Status.CONFIRMED || status_ == Status.CANCELLED) {
        if (msg.value > 0) revert CannotReceive();
        release();
        return;
      }
    }

    if (_chip != address(0)) revert InvalidChip();
    if (AddressLib.isContractSender()) revert CannotReceive();
    dispute(msg.value);
  }
}
