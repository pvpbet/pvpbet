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

    unchecked {
      _chipPerQuantity = 10 ** _chip.decimals();
      _votePerQuantity = 10 ** _vote.decimals();
      if (_chip == address(0)) {
        _minWageredTotalAmount = _config.minWageredTotalAmountETH;
      } else {
        _minWageredTotalAmount = _config.minWageredTotalQuantityERC20.unsafeMul(_chipPerQuantity);
      }
      _minDecidedTotalAmount = _config.minDecidedTotalQuantity.unsafeMul(_votePerQuantity);
      _minArbitratedTotalAmount = _config.minArbitratedTotalQuantity.unsafeMul(_votePerQuantity);
    }

    IBetOptionFactory factory = IBetOptionFactory(betOptionFactory);
    uint256 length = details_.options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      _options.push(
        factory.createBetOption(_details.options[i], address(this))
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

  function statusUpdate()
  external {
    (Status status_, address unconfirmedWinningOption_, address confirmedWinningOption_) = _getState();
    _status = status_;
    _unconfirmedWinningOption = unconfirmedWinningOption_;
    _confirmedWinningOption = confirmedWinningOption_;
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

  function release()
  public {
    if (_released) revert BetHasBeenReleased();

    (Status status_, address unconfirmedWinningOption_, address confirmedWinningOption_) = _getState();
    if (status_ != Status.CONFIRMED && status_ != Status.CANCELLED) revert BetHasNotEndedYet();

    _released = true;
    _status = Status.CLOSED;
    _unconfirmedWinningOption = unconfirmedWinningOption_;
    _confirmedWinningOption = confirmedWinningOption_;

    if (status_ == Status.CONFIRMED) {
      if (_arbitratingPeriodStartTime > 0) {
        // Dispute occurred
        IBetActionArbitrate confirmedWinningOptionActionArbitrate = IBetActionArbitrate(confirmedWinningOption_);
        if (confirmedWinningOption_ == unconfirmedWinningOption_) {
          // Punish disputer
          this.collectDisputedChips();
          confirmedWinningOptionActionArbitrate.arbitratedRecords().distribute(
            _chip,
            disputedAmount(),
            confirmedWinningOptionActionArbitrate.arbitratedAmount()
          );
        } else {
          // Punish decider
          IBetActionDecide unconfirmedWinningOptionActionDecide = IBetActionDecide(unconfirmedWinningOption_);
          unconfirmedWinningOptionActionDecide.confiscateDecidedVotes();
          confirmedWinningOptionActionArbitrate.arbitratedRecords().distribute(
            IUseGovToken(_betManager).govToken(),
            unconfirmedWinningOptionActionDecide.decidedAmount(),
            confirmedWinningOptionActionArbitrate.arbitratedAmount()
          );
          _deciderLevelDown(unconfirmedWinningOptionActionDecide.decidedRecords());
        }
      }

      _distribute(confirmedWinningOption_);
    }

    _refund();
    _destroy();
    if (msg.sender != _betManager) {
      IBetManager(_betManager).close();
    }
  }

  function released()
  external view
  returns (bool) {
    return _released;
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

  function _refund()
  private {
    this.refundDisputedChips();
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address option = _options[i];
      IBetActionDecide(option).unfixDecidedVotes();
      IBetActionWager(option).refundWageredChips();
    }
  }

  function _distribute(address winingOption)
  private {
    uint256 total = 0;
    uint256 length = _options.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      IBetActionWager optionActionWager = IBetActionWager(_options[i]);
      optionActionWager.collectWageredChips();
      total = total.unsafeAdd(optionActionWager.wageredAmount());
    }

    uint256 protocolReward = total.mulDiv(_config.protocolRewardRatio, 100);
    uint256 creatorReward = total.mulDiv(_config.creatorRewardRatio, 100);
    uint256 deciderReward = total.mulDiv(_config.deciderRewardRatio, 100);
    uint256 winnerReward = total.unsafeSub(protocolReward).unsafeSub(creatorReward).unsafeSub(deciderReward);

    _creator.transferFromContract(_chip, creatorReward, true);

    IBetActionDecide winingOptionActionDecide = IBetActionDecide(winingOption);
    Record[] memory decidedRecords = winingOptionActionDecide.decidedRecords();
    if (decidedRecords.length > 0) {
      decidedRecords.distribute(_chip, deciderReward, winingOptionActionDecide.decidedAmount());
      _deciderLevelUp(decidedRecords);
    } else {
      protocolReward = protocolReward.unsafeAdd(deciderReward);
    }

    IBetActionWager winingOptionActionWager = IBetActionWager(winingOption);
    Record[] memory wageredRecords = winingOptionActionWager.wageredRecords();
    if (wageredRecords.length > 0) {
      wageredRecords.distribute(_chip, winnerReward, winingOptionActionWager.wageredAmount());
    } else {
      protocolReward = protocolReward.unsafeAdd(winnerReward);
    }

    _distributeStakeReward(protocolReward);
  }

  function _distributeStakeReward(uint256 amount)
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
    if (status_ == Status.CLOSED) {
      if (msg.sender.isBetOption()) return;
      revert CannotReceive();
    } else if (status_ == Status.CONFIRMED || status_ == Status.CANCELLED) {
      if (msg.value > 0) revert CannotReceive();
      release();
      return;
    }

    if (_chip != address(0)) revert InvalidChip();
    if (AddressLib.isContractSender()) revert CannotReceive();
    dispute(msg.value);
  }
}
