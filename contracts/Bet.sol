// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BetActionArbitrate} from "./base/BetActionArbitrate.sol";
import {BetActionDispute} from "./base/BetActionDispute.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetActionDecide} from "./interface/IBetActionDecide.sol";
import {IBetActionWager} from "./interface/IBetActionWager.sol";
import {IBetOptionFactory} from "./interface/IBetOptionFactory.sol";
import {IGovTokenStaking} from "./interface/IGovTokenStaking.sol";
import {IUseGovTokenStaking} from "./interface/IUseGovTokenStaking.sol";
import {IMetadata} from "./interface/IMetadata.sol";
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
  address private _govToken;
  address private _govTokenStaking;
  address private _betManager;
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
    address govToken_,
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
    _govToken = govToken_;
    _govTokenStaking = IUseGovTokenStaking(vote_).govTokenStaking();
    _betManager = betManager;
    _calculateParameters();
    _createBetOptions(betOptionFactory);
  }

  function _calculateParameters()
  private {
    unchecked {
      _chipPerQuantity = 10 ** _chip.decimals();
      _votePerQuantity = 10 ** _vote.decimals();
      _minWageredTotalAmount = _chip == address(0)
        ? _config.minWageredTotalAmountETH
        : _config.minWageredTotalQuantityERC20.unsafeMul(_chipPerQuantity);
      _minDecidedTotalAmount = _config.minDecidedTotalQuantity.unsafeMul(_votePerQuantity);
      _minArbitratedTotalAmount = _config.minArbitratedTotalQuantity.unsafeMul(_votePerQuantity);
    }
  }

  function _createBetOptions(address betOptionFactory)
  private {
    IBetOptionFactory factory = IBetOptionFactory(betOptionFactory);
    uint256 length = _details.options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      _options.push(
        factory.createBetOption(
          _details.options[i],
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
    (,address unconfirmedWinningOption_,,,,) = _getState();
    return unconfirmedWinningOption_;
  }

  function confirmedWinningOption()
  external view
  returns (address) {
    (,,address confirmedWinningOption_,,,) = _getState();
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
      total = total.unsafeAdd(BetActionArbitrate(_options[i]).arbitratedAmount());
    }
    return total;
  }

  function status()
  public view
  returns (Status) {
    (Status status_,,,,,) = _getState();
    return status_;
  }

  function statusUpdate()
  external
  returns (Status) {
    (Status status_, address unconfirmedWinningOption_, address confirmedWinningOption_,,,) = _getState();
    _status = status_;
    _unconfirmedWinningOption = unconfirmedWinningOption_;
    _confirmedWinningOption = confirmedWinningOption_;
    return status_;
  }

  function _getState()
  private view
  returns (
    Status status_,
    address unconfirmedWinningOption_,
    address confirmedWinningOption_,
    bool isPenaltyDisputer_,
    bool isPenaltyDecider_,
    uint256 maxReleaseCount_
  ) {
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

    if (status_ == Status.CONFIRMED && _arbitratingPeriodStartTime > 0) {
      if (confirmedWinningOption_ == unconfirmedWinningOption_) {
        isPenaltyDisputer_ = true;
      } else {
        isPenaltyDecider_ = true;
      }
    }

    maxReleaseCount_ = _calculateMaxReleaseCount(
      status_,
      unconfirmedWinningOption_,
      confirmedWinningOption_,
      isPenaltyDisputer_,
      isPenaltyDecider_
    );

    return (
      status_,
      unconfirmedWinningOption_,
      confirmedWinningOption_,
      isPenaltyDisputer_,
      isPenaltyDecider_,
      maxReleaseCount_
    );
  }

  function _calculateMaxReleaseCount(
    Status status_,
    address unconfirmedWinningOption_,
    address confirmedWinningOption_,
    bool isPenaltyDisputer_,
    bool isPenaltyDecider_
  )
  public view
  returns (uint256) {
    uint256 maxReleaseCount_;
    if (status_ < Status.CONFIRMED) return maxReleaseCount_;
    if (status_ == Status.CLOSED) return _releasedOffset;

    if (isPenaltyDisputer_) {
      maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
        BetActionArbitrate(confirmedWinningOption_).arbitratedRecordCount()
      );
    } else {
      maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
        disputedRecordCount()
      );
    }

    if (isPenaltyDecider_) {
      maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
        IBetActionDecide(unconfirmedWinningOption_).decidedRecordCount()
      ).unsafeAdd(
        BetActionArbitrate(confirmedWinningOption_).arbitratedRecordCount()
      );
    }

    if (status_ == Status.CONFIRMED) {
      maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
        IBetActionDecide(confirmedWinningOption_).decidedRecordCount()
      ).unsafeAdd(
        IBetActionWager(confirmedWinningOption_).wageredRecordCount()
      );
    }

    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
        IBetActionDecide(option).decidedRecordCount()
      );
      if (status_ != Status.CONFIRMED) {
        maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
          IBetActionWager(option).wageredRecordCount()
        );
      }
    }

    // + 1 for destroy
    return maxReleaseCount_.unsafeInc();
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
      uint256 arbitratedAmount_ = BetActionArbitrate(option).arbitratedAmount();
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

    (
      Status status_,
      address unconfirmedWinningOption_,
      address confirmedWinningOption_,
      bool isPenaltyDisputer_,
      bool isPenaltyDecider_,
      uint256 maxReleaseCount_
    ) = _getState();
    if (status_ != Status.CONFIRMED && status_ != Status.CANCELLED) revert BetHasNotEndedYet();

    _unconfirmedWinningOption = unconfirmedWinningOption_;
    _confirmedWinningOption = confirmedWinningOption_;

    uint256 offset = _releasedOffset;
    if (limit > 0) {
      _releasedOffset = _releasedOffset.add(limit);
    } else {
      _releasedOffset = maxReleaseCount_;
    }

    if (_releasedOffset >= maxReleaseCount_) {
      _releasedOffset = maxReleaseCount_;
      _released = true;
      _status = Status.CLOSED;
    } else {
      _status = status_;
    }

    uint256 start;
    if (isPenaltyDisputer_) {
      start = _penalizeDisputer(start, offset);
      if (_releasedOffset <= start) return;
    } else {
      start = _refundDisputedChips(start, offset);
      if (_releasedOffset <= start) return;
    }

    if (isPenaltyDecider_) {
      start = _penalizeDecider(start, offset);
      if (_releasedOffset <= start) return;
    }

    if (status_ == Status.CONFIRMED) {
      start = _distribute(start, offset);
      if (_releasedOffset <= start) return;
    }

    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      start = _unfixDecidedVotes(option, start, offset);
      if (_releasedOffset <= start) return;

      if (status_ != Status.CONFIRMED) {
        start = _refundWageredChips(option, start, offset);
        if (_releasedOffset <= start) return;
      }
    }

    _destroy();
  }

  function maxReleaseCount()
  external view
  returns (uint256) {
    (,,,,,uint256 maxReleaseCount_) = _getState();
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

  function _penalizeDisputer(uint256 start, uint256 offset)
  private
  returns (uint256) {
    BetActionArbitrate actionArbitrate = BetActionArbitrate(_confirmedWinningOption);
    uint256 count = actionArbitrate.arbitratedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (_releasedOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, _releasedOffset);
      if (relativeOffset == 0) this.collectDisputedChips();
      (
        relativeOffset == 0 && relativeLimit >= count
          ? actionArbitrate.arbitratedRecords()
          : actionArbitrate.arbitratedRecords(relativeOffset, relativeLimit)
      ).distribute(
        _chip,
        disputedAmount(),
        actionArbitrate.arbitratedAmount()
      );
    }

    return end;
  }

  function _penalizeDecider(uint256 start, uint256 offset)
  private
  returns (uint256) {
    IBetActionDecide actionDecide = IBetActionDecide(_unconfirmedWinningOption);
    uint256 count = actionDecide.decidedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (_releasedOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, _releasedOffset);

      if (relativeOffset == 0 && relativeLimit >= count) {
        actionDecide.confiscateDecidedVotes();
      } else {
        actionDecide.confiscateDecidedVotes(relativeLimit);
      }
    }

    start = end;
    if (_releasedOffset <= start) return end;

    return _distributeConfiscatedAmount(actionDecide.decidedAmount(), start, offset);
  }

  function _distributeConfiscatedAmount(uint256 confiscatedAmount, uint256 start, uint256 offset)
  private
  returns (uint256) {
    BetActionArbitrate actionArbitrate = BetActionArbitrate(_confirmedWinningOption);
    uint256 count = actionArbitrate.arbitratedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (_releasedOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, _releasedOffset);
      (
        relativeOffset == 0 && relativeLimit >= count
          ? actionArbitrate.arbitratedRecords()
          : actionArbitrate.arbitratedRecords(relativeOffset, relativeLimit)
      ).distribute(
        _govToken,
        confiscatedAmount,
        actionArbitrate.arbitratedAmount()
      );
    }

    return end;
  }

  function _distribute(uint256 start, uint256 offset)
  private
  returns (uint256) {
    uint256 total = _releasedOffset > start && offset <= start
      ? _collectWageredChips()
      : wageredTotalAmount();

    uint256 protocolReward = total.mulDiv(_config.protocolRewardRatio, 100);
    uint256 creatorReward = total.mulDiv(_config.creatorRewardRatio, 100);
    uint256 deciderReward = total.mulDiv(_config.deciderRewardRatio, 100);
    uint256 winnerReward = total.unsafeSub(protocolReward).unsafeSub(creatorReward).unsafeSub(deciderReward);

    if (_releasedOffset > start && offset <= start) {
      _creator.transferFromContract(_chip, creatorReward, true);
    }

    uint256 end = _distributeDeciderReward(deciderReward, start, offset);
    if (start == end) {
      protocolReward = protocolReward.unsafeAdd(deciderReward);
    }
    start = end;
    if (_releasedOffset <= start) return end;

    end = _distributeWinnerReward(winnerReward, start, offset);
    if (start == end) {
      protocolReward = protocolReward.unsafeAdd(winnerReward);
    }
    start = end;
    if (_releasedOffset <= start) return end;

    if (_releasedOffset > start && offset <= start) {
      _distributeProtocolReward(protocolReward);
    }

    return end;
  }

  function _distributeDeciderReward(uint256 amount, uint256 start, uint256 offset)
  private
  returns (uint256) {
    IBetActionDecide actionDecide = IBetActionDecide(_confirmedWinningOption);
    uint256 count = actionDecide.decidedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (_releasedOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, _releasedOffset);
      (
        relativeOffset == 0 && relativeLimit >= count
          ? actionDecide.decidedRecords()
          : actionDecide.decidedRecords(relativeOffset, relativeLimit)
      ).distribute(_chip, amount, actionDecide.decidedAmount());
    }

    return end;
  }

  function _distributeWinnerReward(uint256 amount, uint256 start, uint256 offset)
  private
  returns (uint256) {
    IBetActionWager actionWager = IBetActionWager(_confirmedWinningOption);
    uint256 count = actionWager.wageredRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (_releasedOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, _releasedOffset);
      (
        relativeOffset == 0 && relativeLimit >= count
          ? actionWager.wageredRecords()
          : actionWager.wageredRecords(relativeOffset, relativeLimit)
      ).distribute(_chip, amount, actionWager.wageredAmount());
    }

    return end;
  }

  function _distributeProtocolReward(uint256 amount)
  private {
    if (_chip == address(0)) {
      _govTokenStaking.functionCallWithValue(
        abi.encodeWithSignature("distribute()"),
        amount
      );
    } else {
      IERC20(_chip).approve(_govTokenStaking, amount);
      IGovTokenStaking(_govTokenStaking).distribute(_chip, amount);
    }
  }

  function _refundDisputedChips(uint256 start, uint256 offset)
  private
  returns (uint256) {
    uint256 count = disputedRecordCount();
    uint256 end = start.unsafeAdd(count);
    if (_releasedOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, _releasedOffset);

      if (relativeOffset == 0 && relativeLimit >= count) {
        this.refundDisputedChips();
      } else {
        this.refundDisputedChips(relativeLimit);
      }
    }
    return end;
  }

  function _unfixDecidedVotes(address option, uint256 start, uint256 offset)
  private
  returns (uint256) {
    IBetActionDecide actionDecide = IBetActionDecide(option);
    uint256 count = actionDecide.decidedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (_releasedOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, _releasedOffset);

      if (relativeOffset == 0 && relativeLimit >= count) {
        actionDecide.unfixDecidedVotes();
      } else {
        actionDecide.unfixDecidedVotes(relativeLimit);
      }
    }

    return end;
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

  function _refundWageredChips(address option, uint256 start, uint256 offset)
  private
  returns (uint256) {
    IBetActionWager actionWager = IBetActionWager(option);
    uint256 count = actionWager.wageredRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (_releasedOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, _releasedOffset);

      if (relativeOffset == 0 && relativeLimit >= count) {
        actionWager.refundWageredChips();
      } else {
        actionWager.refundWageredChips(relativeLimit);
      }
    }

    return end;
  }

  function _getRelativeOffsetAndLimit(uint256 start, uint256 end, uint256 offset, uint256 releasedOffset_)
  private pure
  returns (uint256 relativeOffset, uint256 relativeLimit) {
    relativeOffset = offset > start ? offset.unsafeSub(start) : 0;
    relativeLimit = releasedOffset_.min(end).unsafeSub(start).unsafeSub(relativeOffset);
    return (relativeOffset, relativeLimit);
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
