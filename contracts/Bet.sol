// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

contract Bet is IBet, IMetadata, BetActionArbitrate, BetActionDispute {
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

  address private constant ZERO_ADDRESS = address(0);

  string private _version;
  BetConfig private _config;
  BetDetails private _details;
  address[] private _options;

  address private immutable _creator;
  address private immutable _chip;
  address private immutable _vote;
  address private immutable _betManager;
  uint256 private immutable _wageringPeriodDeadline;
  uint256 private immutable _decidingPeriodDeadline;

  uint256 private _arbitratingPeriodStartTime;
  address private _unconfirmedWinningOption;
  address private _confirmedWinningOption;
  bool private _released;

  constructor(
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
  ) {
    _version = version_;
    _config = config_;
    _details = details_;
    _wageringPeriodDeadline = block.timestamp.unsafeAdd(wageringPeriodDuration);
    _decidingPeriodDeadline = _wageringPeriodDeadline.unsafeAdd(decidingPeriodDuration);
    _creator = creator_;
    _chip = chip_;
    _vote = vote_;
    _betManager = betManager;

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
    if (_chip == ZERO_ADDRESS) {
      return 0.001 ether;
    } else {
      return 10 ** _chip.decimals();
    }
  }

  function voteMinValue()
  public view override(IBet, BetActionArbitrate)
  returns (uint256) {
    return 10 ** _vote.decimals();
  }

  function minWageredTotalAmount()
  public view
  returns (uint256) {
    if (_chip == ZERO_ADDRESS) {
      return _config.minWageredTotalAmountETH;
    } else {
      return _config.minWageredTotalAmountERC20 * 10 ** _chip.decimals();
    }
  }

  function minDecidedTotalAmount()
  public view
  returns (uint256) {
    return _config.minDecidedTotalAmount * 10 ** _vote.decimals();
  }

  function minDisputedTotalAmount()
  public view
  returns (uint256) {
    return wageredTotalAmount().mulDiv(_config.confirmDisputeAmountRatio, 100);
  }

  function minArbitratedTotalAmount()
  public view
  returns (uint256) {
    return _config.minArbitratedTotalAmount * 10 ** _vote.decimals();
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
    if (_released) {
      return (Status.CLOSED, _unconfirmedWinningOption, _confirmedWinningOption);
    }

    status_ = Status.WAGERING;
    unconfirmedWinningOption_ = ZERO_ADDRESS;
    confirmedWinningOption_ = ZERO_ADDRESS;

    if (status_ == Status.WAGERING && block.timestamp > _wageringPeriodDeadline) {
      if (_isValidWager()) {
        status_ = Status.DECIDING;
      } else {
        status_ = Status.CANCELLED;
      }
    }

    if (status_ == Status.DECIDING && block.timestamp > _decidingPeriodDeadline) {
      unconfirmedWinningOption_ = _getDecidedWinningOption();
      if (unconfirmedWinningOption_ != ZERO_ADDRESS) {
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
      if (confirmedWinningOption_ != ZERO_ADDRESS) {
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

  function release()
  public {
    if (_released) revert BetHasBeenReleased();

    (Status status_, address unconfirmedWinningOption_, address confirmedWinningOption_) = _getState();
    if (status_ != Status.CONFIRMED && status_ != Status.CANCELLED) revert BetHasNotEndedYet();

    _released = true;
    _unconfirmedWinningOption = unconfirmedWinningOption_;
    _confirmedWinningOption = confirmedWinningOption_;

    if (status_ == Status.CONFIRMED) {
      if (_arbitratingPeriodStartTime > 0) {
        // Dispute occurred
        Record[] memory records = IBetActionArbitrate(confirmedWinningOption_).arbitratedRecords();
        if (confirmedWinningOption_ == unconfirmedWinningOption_) {
          // Punish disputer
          this.collectDisputedChips();
          records.distribute(_chip, disputedAmount());
        } else {
          // Punish decider
          IBetActionDecide action = IBetActionDecide(unconfirmedWinningOption_);
          action.confiscateDecidedVotes();
          records.distribute(IUseGovToken(_betManager).govToken(), action.decidedAmount());
          _deciderLevelDown(action.decidedRecords());
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

    if (total < minWageredTotalAmount()) {
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
    address winningOption = ZERO_ADDRESS;
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
      } else if (decidedAmount_ == max && winningOption != ZERO_ADDRESS) {
        winningOption = ZERO_ADDRESS;
      }
    }
    if (total < minDecidedTotalAmount()) return ZERO_ADDRESS;
    return winningOption;
  }

  function _getArbitratedWinningOption()
  private view
  returns (address) {
    if (_arbitratingPeriodStartTime == 0) return ZERO_ADDRESS;
    address winningOption = ZERO_ADDRESS;
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
      } else if (arbitratedAmount_ == max && winningOption != ZERO_ADDRESS) {
        winningOption = ZERO_ADDRESS;
      }
    }
    if (total < minArbitratedTotalAmount()) return ZERO_ADDRESS;
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
      address option = _options[i];
      IBetActionWager action = IBetActionWager(option);
      action.collectWageredChips();
      total = total.unsafeAdd(action.wageredAmount());
    }

    uint256 protocolReward = total.mulDiv(_config.protocolRewardRatio, 100);
    uint256 creatorReward = total.mulDiv(_config.creatorRewardRatio, 100);
    uint256 deciderReward = total.mulDiv(_config.deciderRewardRatio, 100);
    uint256 winnerReward = total.unsafeSub(protocolReward).unsafeSub(creatorReward).unsafeSub(deciderReward);

    _creator.transferFromContract(_chip, creatorReward, true);

    Record[] memory decidedRecords = IBetActionDecide(winingOption).decidedRecords();
    if (decidedRecords.length > 0) {
      decidedRecords.distribute(_chip, deciderReward);
      _deciderLevelUp(decidedRecords);
    } else {
      protocolReward = protocolReward.unsafeAdd(deciderReward);
    }

    Record[] memory wageredRecords = IBetActionWager(winingOption).wageredRecords();
    if (wageredRecords.length > 0) {
      wageredRecords.distribute(_chip, winnerReward);
    } else {
      protocolReward = protocolReward.unsafeAdd(winnerReward);
    }

    _distributeStakeReward(protocolReward);
  }

  function _distributeStakeReward(uint256 amount)
  private {
    if (_chip == ZERO_ADDRESS) {
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
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      IAccountLevel(_vote).levelUp(records[i].account);
    }
  }

  function _deciderLevelDown(Record[] memory records)
  private {
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      IAccountLevel(_vote).levelDown(records[i].account);
    }
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

    if (_chip != ZERO_ADDRESS) revert InvalidChip();
    if (AddressLib.isContractSender()) revert CannotReceive();
    dispute(msg.value);
  }
}
