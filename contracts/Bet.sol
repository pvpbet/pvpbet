// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BetActionArbitrate} from "./base/BetActionArbitrate.sol";
import {BetActionDispute} from "./base/BetActionDispute.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetActionVerify} from "./interface/IBetActionVerify.sol";
import {IBetActionWager} from "./interface/IBetActionWager.sol";
import {IBetOptionFactory} from "./interface/IBetOptionFactory.sol";
import {IErrors} from "./interface/IErrors.sol";
import {IGovTokenStaking} from "./interface/IGovTokenStaking.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {IUseGovTokenStaking} from "./interface/IUseGovTokenStaking.sol";
import {AddressLib} from "./lib/Address.sol";
import {MathLib} from "./lib/Math.sol";
import {Record, RecordArrayLib} from "./lib/Record.sol";
import {TransferLib} from "./lib/Transfer.sol";

contract Bet is IBet, IErrors, IMetadata, BetActionArbitrate, BetActionDispute {
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

  error BetHasNotEndedYet();
  error BetHasBeenPenalized();
  error BetHasBeenReleased();
  error InvalidInitialization();
  error NoTargetForPenalty();

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
  uint256 private _verifyingPeriodDeadline;
  uint256 private _arbitratingPeriodStartTime;

  uint256 private _releasedOffset;
  uint256 private _penalizedOffset;
  bool private _released;
  bool private _penalized;
  bool private _initialized;

  function initialize(
    string calldata version_,
    BetConfig calldata config_,
    BetDetails calldata details_,
    uint256 wageringPeriodDuration,
    uint256 verifyingPeriodDuration,
    address creator_,
    address chip_,
    address vote_,
    address govToken_,
    address betManager,
    address betOptionFactory
  )
  public {
    if (_initialized) revert InvalidInitialization();
    _initialized = true;
    _version = version_;
    _config = config_;
    _details = details_;
    _wageringPeriodDeadline = block.timestamp.unsafeAdd(wageringPeriodDuration);
    _verifyingPeriodDeadline = _wageringPeriodDeadline.unsafeAdd(verifyingPeriodDuration);
    _creator = creator_;
    _chip = chip_;
    _vote = vote_;
    _govToken = govToken_;
    _govTokenStaking = IUseGovTokenStaking(vote_).govTokenStaking();
    _betManager = betManager;

    _createBetOptions(betOptionFactory, config_, details_, chip_, vote_);
  }

  function _createBetOptions(
    address betOptionFactory,
    BetConfig calldata config_,
    BetDetails calldata details_,
    address chip_,
    address vote_
  )
  private {
    IBetOptionFactory factory = IBetOptionFactory(betOptionFactory);
    uint256 length = details_.options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      _options.push(
        factory.createBetOption(
          details_.options[i],
          config_,
          address(this),
          chip_,
          vote_
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

  function verifyingPeriodDeadline()
  external view
  returns (uint256) {
    return _verifyingPeriodDeadline;
  }

  function arbitratingPeriodStartTime()
  external view
  returns (uint256) {
    return _arbitratingPeriodStartTime;
  }

  function unconfirmedWinningOption()
  external view
  returns (address) {
    (,address unconfirmedWinningOption_,,,,,) = _getState();
    return unconfirmedWinningOption_;
  }

  function confirmedWinningOption()
  external view
  returns (address) {
    (,,address confirmedWinningOption_,,,,) = _getState();
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
    return _config.chipMinValue;
  }

  function voteMinValue()
  public view override(IBet, BetActionArbitrate)
  returns (uint256) {
    return _config.voteMinValue;
  }

  function minWageredTotalAmount()
  public view
  returns (uint256) {
    return _config.minWageredTotalAmount;
  }

  function minVerifiedTotalAmount()
  public view
  returns (uint256) {
    return wageredTotalAmount().mul(_config.verificationRatio);
  }

  function minDisputedTotalAmount()
  public view
  returns (uint256) {
    return wageredTotalAmount().mulDiv(_config.confirmDisputeAmountRatio, 100);
  }

  function minArbitratedTotalAmount()
  public view
  returns (uint256) {
    return verifiedTotalAmount();
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

  function verifiedTotalAmount()
  public view
  returns (uint256) {
    uint256 total = 0;
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      total = total.unsafeAdd(IBetActionVerify(_options[i]).verifiedAmount());
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
  returns (Status status_) {
    (status_,,,,,,) = _getState();
  }

  function statusUpdate()
  external
  returns (Status) {
    (Status status_, address unconfirmedWinningOption_, address confirmedWinningOption_,,,,) = _getState();
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
    bool isPenaltyVerifier_,
    uint256 maxReleaseCount_,
    uint256 maxPenalizeCount_
  ) {
    status_ = _status;
    unconfirmedWinningOption_ = _unconfirmedWinningOption;
    confirmedWinningOption_ = _confirmedWinningOption;
    isPenaltyDisputer_ = false;
    isPenaltyVerifier_ = false;
    maxReleaseCount_ = 0;
    maxPenalizeCount_ = 0;

    if (status_ == Status.WAGERING && block.timestamp > _wageringPeriodDeadline) {
      if (_isValidWager()) {
        status_ = Status.VERIFYING;
      } else if (wageredTotalAmount() == 0) {
        status_ = Status.CLOSED;
      } else {
        status_ = Status.CANCELLED;
      }
    }

    if (status_ == Status.VERIFYING && block.timestamp > _verifyingPeriodDeadline) {
      unconfirmedWinningOption_ = _getVerifiedWinningOption();
      if (unconfirmedWinningOption_ != address(0)) {
        status_ = Status.ANNOUNCEMENT;
      } else {
        status_ = Status.CANCELLED;
      }
    }

    if (status_ == Status.ANNOUNCEMENT) {
      if (_arbitratingPeriodStartTime > 0) {
        status_ = Status.ARBITRATING;
      } else if (block.timestamp > _verifyingPeriodDeadline.unsafeAdd(_config.announcementPeriodDuration)) {
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

    if (_arbitratingPeriodStartTime > 0 && confirmedWinningOption_ != address(0)) {
      if (confirmedWinningOption_ == unconfirmedWinningOption_) {
        isPenaltyDisputer_ = true;
      } else {
        isPenaltyVerifier_ = true;
      }
    }

    if (status_ >= Status.CONFIRMED) {
      maxReleaseCount_ = _calculateMaxReleaseCount(
        unconfirmedWinningOption_,
        confirmedWinningOption_,
        isPenaltyDisputer_,
        isPenaltyVerifier_
      );

      maxPenalizeCount_ = _calculateMaxPenalizeCount(
        unconfirmedWinningOption_,
        confirmedWinningOption_,
        isPenaltyDisputer_,
        isPenaltyVerifier_
      );
    }
  }

  function _calculateMaxReleaseCount(
    address unconfirmedWinningOption_,
    address confirmedWinningOption_,
    bool isPenaltyDisputer_,
    bool isPenaltyVerifier_
  )
  internal view
  returns (uint256) {
    if (_released) return _releasedOffset;

    uint256 maxReleaseCount_;
    bool isConfirmed = confirmedWinningOption_ != address(0);

    if (!isPenaltyDisputer_) {
      maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
        disputedRecordCount()
      );
    }

    if (isConfirmed) {
      maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
        IBetActionVerify(confirmedWinningOption_).verifiedRecordCount()
      ).unsafeAdd(
        IBetActionWager(confirmedWinningOption_).wageredRecordCount()
      );
    }

    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      if (!isPenaltyVerifier_ || option != unconfirmedWinningOption_) {
        maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
          IBetActionVerify(option).verifiedRecordCount()
        );
      }

      if (!isConfirmed) {
        maxReleaseCount_ = maxReleaseCount_.unsafeAdd(
          IBetActionWager(option).wageredRecordCount()
        );
      }
    }

    // + 1 for destroy
    return maxReleaseCount_.unsafeInc();
  }

  function _calculateMaxPenalizeCount(
    address unconfirmedWinningOption_,
    address confirmedWinningOption_,
    bool isPenaltyDisputer_,
    bool isPenaltyVerifier_
  )
  internal view
  returns (uint256) {
    if (_penalized) return _penalizedOffset;

    uint256 maxPenalizeCount_;

    if (isPenaltyDisputer_) {
      maxPenalizeCount_ = maxPenalizeCount_.unsafeAdd(
        BetActionArbitrate(confirmedWinningOption_).arbitratedRecordCount()
      );
    } else if (isPenaltyVerifier_) {
      maxPenalizeCount_ = maxPenalizeCount_.unsafeAdd(
        IBetActionVerify(unconfirmedWinningOption_).verifiedRecordCount()
      ).unsafeAdd(
        BetActionArbitrate(confirmedWinningOption_).arbitratedRecordCount()
      );
    }

    return maxPenalizeCount_;
  }

  function statusDeadline()
  external view
  returns (uint256) {
    Status status_ = status();
    if (status_ == Status.WAGERING) {
      return _wageringPeriodDeadline;
    } else if (status_ == Status.VERIFYING) {
      return _verifyingPeriodDeadline;
    } else if (status_ == Status.ANNOUNCEMENT) {
      return _verifyingPeriodDeadline.unsafeAdd(_config.announcementPeriodDuration);
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

  function dispute(uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature)
  public override(BetActionDispute) {
    super.dispute(amount, nonce, deadline, signature);
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
    uint256 max = 0;
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      uint256 wageredAmount = IBetActionWager(_options[i]).wageredAmount();
      if (wageredAmount > max) max = wageredAmount;
      total = total.unsafeAdd(wageredAmount);
    }

    if (total < _config.minWageredTotalAmount) return false;

    uint256 singleOptionMaxAmount = total.mulDiv(_config.singleOptionMaxAmountRatio, 100);
    if (max > singleOptionMaxAmount) return false;

    return true;
  }

  function _isValidDispute()
  private view
  returns (bool) {
    return disputedAmount() >= minDisputedTotalAmount();
  }

  function _getVerifiedWinningOption()
  private view
  returns (address) {
    address winningOption = address(0);
    uint256 max = 0;
    uint256 total = 0;
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      uint256 verifiedAmount_ = IBetActionVerify(option).verifiedAmount();
      total = total.unsafeAdd(verifiedAmount_);
      if (verifiedAmount_ > max) {
        max = verifiedAmount_;
        winningOption = option;
      } else if (verifiedAmount_ == max && winningOption != address(0)) {
        winningOption = address(0);
      }
    }
    if (total < minVerifiedTotalAmount()) return address(0);
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
    if (total < minArbitratedTotalAmount()) return address(0);
    return winningOption;
  }

  function release()
  public {
    if (
      _released
      && _arbitratingPeriodStartTime > 0
      && _confirmedWinningOption != address(0)
      && !_penalized
    ) {
      penalize();
      return;
    }
    release(_config.countPerRelease);
  }

  function release(uint256 limit)
  public {
    if (_released) revert BetHasBeenReleased();

    (
      Status status_,
      address unconfirmedWinningOption_,
      address confirmedWinningOption_,
      bool isPenaltyDisputer_,
      bool isPenaltyVerifier_,
      uint256 maxReleaseCount_,
    ) = _getState();

    bool isPenaltyRequired = isPenaltyDisputer_ || isPenaltyVerifier_;
    if (status_ < Status.CONFIRMED) revert BetHasNotEndedYet();

    _unconfirmedWinningOption = unconfirmedWinningOption_;
    _confirmedWinningOption = confirmedWinningOption_;

    uint256 offset = _releasedOffset;
    uint256 targetOffset = _releasedOffset = offset.add(limit).min(maxReleaseCount_);

    emit Released(msg.sender, targetOffset - offset);

    if (targetOffset == maxReleaseCount_) {
      _released = true;
      _status = (!isPenaltyRequired || _penalized) ? Status.CLOSED : status_;
    } else {
      _status = status_;
    }

    uint256 start;
    if (!isPenaltyDisputer_) {
      start = _refundDisputedChips(start, offset, targetOffset);
      if (targetOffset <= start) return;
    }

    if (status_ == Status.CONFIRMED) {
      start = _distribute(start, offset, targetOffset);
      if (targetOffset <= start) return;
    }

    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      if (!isPenaltyVerifier_ || option != unconfirmedWinningOption_) {
        start = _unfixVerifiedVotes(option, start, offset, targetOffset);
        if (targetOffset <= start) return;
      }

      if (status_ != Status.CONFIRMED) {
        start = _refundWageredChips(option, start, offset, targetOffset);
        if (targetOffset <= start) return;
      }
    }

    if (_released && (!isPenaltyRequired || _penalized)) {
      _destroy();
    }
  }

  function releasedProgress()
  external view
  returns (uint256, uint256) {
    (,,,,,uint256 maxReleaseCount_,) = _getState();
    return (_releasedOffset, maxReleaseCount_);
  }

  function released()
  external view
  returns (bool) {
    return _released;
  }

  function _distribute(uint256 start, uint256 offset, uint256 targetOffset)
  private
  returns (uint256) {
    uint256 total = targetOffset > start && offset <= start
      ? _collectWageredChips()
      : wageredTotalAmount();

    uint256 protocolReward = total.mulDiv(_config.protocolRewardRatio, 100);
    uint256 creatorReward = total.mulDiv(_config.creatorRewardRatio, 100);
    uint256 verifierReward = total.mulDiv(_config.verifierRewardRatio, 100);
    uint256 winnerReward = total.unsafeSub(protocolReward).unsafeSub(creatorReward).unsafeSub(verifierReward);

    if (targetOffset > start && offset <= start) {
      _creator.transferFromContract(_chip, creatorReward, true);
    }

    uint256 end = _distributeVerifierReward(verifierReward, start, offset, targetOffset);
    if (start == end) {
      protocolReward = protocolReward.unsafeAdd(verifierReward);
    }
    start = end;
    if (targetOffset <= start) return end;

    end = _distributeWinnerReward(winnerReward, start, offset, targetOffset);
    if (start == end) {
      protocolReward = protocolReward.unsafeAdd(winnerReward);
    }
    start = end;
    if (targetOffset <= start) return end;

    if (targetOffset > start && offset <= start) {
      _distributeProtocolReward(protocolReward);
    }

    return end;
  }

  function _distributeVerifierReward(uint256 amount, uint256 start, uint256 offset, uint256 targetOffset)
  private
  returns (uint256) {
    IBetActionVerify actionVerify = IBetActionVerify(_confirmedWinningOption);
    uint256 count = actionVerify.verifiedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (targetOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, targetOffset);
      actionVerify.verifiedRecords(relativeOffset, relativeLimit)
        .distribute(_chip, amount, actionVerify.verifiedAmount());
    }

    return end;
  }

  function _distributeWinnerReward(uint256 amount, uint256 start, uint256 offset, uint256 targetOffset)
  private
  returns (uint256) {
    IBetActionWager actionWager = IBetActionWager(_confirmedWinningOption);
    uint256 count = actionWager.wageredRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (targetOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, targetOffset);
      actionWager.wageredRecords(relativeOffset, relativeLimit)
        .distribute(_chip, amount, actionWager.wageredAmount());
    }

    return end;
  }

  function _distributeProtocolReward(uint256 amount)
  private {
    if (_chip == address(0)) {
      IGovTokenStaking(_govTokenStaking).distribute{value: amount}();
    } else {
      IERC20(_chip).approve(_govTokenStaking, amount);
      IGovTokenStaking(_govTokenStaking).distribute(_chip, amount);
    }
  }

  function _refundDisputedChips(uint256 start, uint256 offset, uint256 targetOffset)
  private
  returns (uint256) {
    uint256 count = disputedRecordCount();
    uint256 end = start.unsafeAdd(count);
    if (targetOffset > start && offset < end) {
      (,uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, targetOffset);
      this.refundDisputedChips(relativeLimit);
    }
    return end;
  }

  function _unfixVerifiedVotes(address option, uint256 start, uint256 offset, uint256 targetOffset)
  private
  returns (uint256) {
    IBetActionVerify actionVerify = IBetActionVerify(option);
    uint256 count = actionVerify.verifiedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (targetOffset > start && offset < end) {
      (,uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, targetOffset);
      actionVerify.unfixVerifiedVotes(relativeLimit);
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

  function _refundWageredChips(address option, uint256 start, uint256 offset, uint256 targetOffset)
  private
  returns (uint256) {
    IBetActionWager actionWager = IBetActionWager(option);
    uint256 count = actionWager.wageredRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (targetOffset > start && offset < end) {
      (,uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, targetOffset);
      actionWager.refundWageredChips(relativeLimit);
    }

    return end;
  }

  function penalize()
  public {
    penalize(_config.countPerPenalize);
  }

  function penalize(uint256 limit)
  public {
    if (_penalized) revert BetHasBeenPenalized();

    (
      Status status_,
      address unconfirmedWinningOption_,
      address confirmedWinningOption_,
      bool isPenaltyDisputer_,
      bool isPenaltyVerifier_,,
      uint256 maxPenalizeCount_
    ) = _getState();

    if (!isPenaltyDisputer_ && !isPenaltyVerifier_) revert NoTargetForPenalty();
    if (status_ < Status.CONFIRMED) revert BetHasNotEndedYet();

    _unconfirmedWinningOption = unconfirmedWinningOption_;
    _confirmedWinningOption = confirmedWinningOption_;

    uint256 offset = _penalizedOffset;
    uint256 targetOffset = _penalizedOffset = offset.add(limit).min(maxPenalizeCount_);

    emit Penalized(msg.sender, targetOffset - offset);

    if (targetOffset == maxPenalizeCount_) {
      _penalized = true;
      _status = _released ? Status.CLOSED : status_;
    } else {
      _status = status_;
    }

    uint256 start;
    if (isPenaltyDisputer_) {
      start = _penalizeDisputer(start, offset, targetOffset);
      if (targetOffset <= start) return;
    } else if (isPenaltyVerifier_) {
      start = _penalizeVerifier(start, offset, targetOffset);
      if (targetOffset <= start) return;
    }

    if (_penalized && _released) {
      _destroy();
    }
  }

  function penalizedProgress()
  external view
  returns (uint256, uint256) {
    (,,,,,,uint256 maxPenalizeCount_) = _getState();
    return (_penalizedOffset, maxPenalizeCount_);
  }

  function penalized()
  external view
  returns (bool) {
    return _penalized;
  }

  function _penalizeDisputer(uint256 start, uint256 offset, uint256 targetOffset)
  private
  returns (uint256) {
    BetActionArbitrate actionArbitrate = BetActionArbitrate(_confirmedWinningOption);
    uint256 count = actionArbitrate.arbitratedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (targetOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, targetOffset);
      if (relativeOffset == 0) this.collectDisputedChips();
      actionArbitrate.arbitratedRecords(relativeOffset, relativeLimit)
        .distribute(_chip, disputedAmount(), actionArbitrate.arbitratedAmount());
    }

    return end;
  }

  function _penalizeVerifier(uint256 start, uint256 offset, uint256 targetOffset)
  private
  returns (uint256) {
    IBetActionVerify actionVerify = IBetActionVerify(_unconfirmedWinningOption);
    uint256 count = actionVerify.verifiedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (targetOffset > start && offset < end) {
      (,uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, targetOffset);
      actionVerify.confiscateVerifiedVotes(relativeLimit);
    }

    start = end;
    if (targetOffset <= start) return end;

    return _distributeConfiscatedAmount(actionVerify.verifiedAmount(), start, offset, targetOffset);
  }

  function _distributeConfiscatedAmount(uint256 confiscatedAmount, uint256 start, uint256 offset, uint256 targetOffset)
  private
  returns (uint256) {
    BetActionArbitrate actionArbitrate = BetActionArbitrate(_confirmedWinningOption);
    uint256 count = actionArbitrate.arbitratedRecordCount();
    uint256 end = start.unsafeAdd(count);

    if (targetOffset > start && offset < end) {
      (uint256 relativeOffset, uint256 relativeLimit) = _getRelativeOffsetAndLimit(start, end, offset, targetOffset);
      actionArbitrate.arbitratedRecords(relativeOffset, relativeLimit)
        .distribute(_govToken, confiscatedAmount, actionArbitrate.arbitratedAmount());
    }

    return end;
  }

  function _getRelativeOffsetAndLimit(uint256 start, uint256 end, uint256 offset, uint256 targetOffset)
  private pure
  returns (uint256 relativeOffset, uint256 relativeLimit) {
    relativeOffset = offset > start ? offset.unsafeSub(start) : 0;
    relativeLimit = targetOffset.min(end).unsafeSub(start).unsafeSub(relativeOffset);
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

    if (_chip != address(0)) revert InvalidChip(_chip);
    if (AddressLib.isContractSender()) revert CannotReceive();
    dispute(msg.value);
  }
}
