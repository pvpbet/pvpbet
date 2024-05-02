// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccountLevel} from "./base/AccountLevel.sol";
import {StakingRewardDistributable} from "./base/StakingRewardDistributable.sol";
import {Staking} from "./base/Staking.sol";
import {Upgradeable} from "./base/Upgradeable.sol";
import {UseGovToken} from "./base/UseGovToken.sol";
import {IBetVotingEscrow} from "./interface/IBetVotingEscrow.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetOption} from "./interface/IBetOption.sol";
import {IBetActionArbitrate} from "./interface/IBetActionArbitrate.sol";
import {IBetActionDecide} from "./interface/IBetActionDecide.sol";
import {IBetManager} from "./interface/IBetManager.sol";
import {IErrors} from "./interface/IErrors.sol";
import {MathLib} from "./lib/Math.sol";
import {AddressLib} from "./lib/Address.sol";
import {TransferLib} from "./lib/Transfer.sol";
import {StakedRecord, StakedRecordLib, StakedRecordArrayLib, UnlockWaitingPeriod} from "./lib/StakedRecord.sol";

contract BetVotingEscrow is IBetVotingEscrow, IErrors, ERC20Upgradeable, Upgradeable, Staking, StakingRewardDistributable, AccountLevel, UseGovToken {
  function name()
  public view override(ERC20Upgradeable, Upgradeable)
  returns (string memory) {
    return ERC20Upgradeable.name();
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

  error InvalidStatus(IBet.Status status);
  error InvalidTarget(address target);
  error VoteConfiscationFailed();
  error VoteConditionsNotMet(address account);
  error VoteInsufficientAvailableBalance(address account, uint256 balance, uint256 value);
  error VoteInsufficientFixedAllowance(address account, uint256 allowance, uint256 value);
  error VoteNotTransferable();

  address private _betManager;
  mapping(address account => uint256 value) private _fixedBalances;
  mapping(address account => mapping(address spender => uint256 value)) private _fixedAllowances;

  function initialize(address initialGovToken)
  public
  initializer {
    Upgradeable.initialize();
    __ERC20_init("PVPBetVotingEscrow", "vePVPB");
    _setGovToken(initialGovToken);
  }

  modifier onlyBet() {
    if (_betManager == address(0) || !IBetManager(_betManager).isBet(msg.sender)) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function _authorizeAccountLevelUpdate(address sender)
  internal view override(AccountLevel) onlyBet {}

  function _authorizeGovTokenUpdate(address sender)
  internal view override(UseGovToken) onlyOwner {}

  function _getStakedRecords()
  internal view override(StakingRewardDistributable)
  returns (StakedRecord[] memory) {
    return __stakedRecords();
  }

  function _mintStakingCertificate(address account, uint256 amount)
  internal override(Staking) {
    _mint(account, amount);
  }

  function _burnStakingCertificate(address account, uint256 amount)
  internal override(Staking) {
    _burn(account, amount);
  }

  function _unstakeAmountCheck(address account, uint256 amount)
  internal view override(Staking) {
    uint256 balance = balanceOf(account);
    if (balance < amount) revert VoteInsufficientAvailableBalance(account, balance, amount);
  }

  function govToken()
  public view override(Staking, UseGovToken)
  returns (address) {
    return UseGovToken.govToken();
  }

  function betManager()
  external view
  returns (address) {
    return _betManager;
  }

  function setBetManager(address newBetManager)
  external
  onlyOwner {
    _setBetManager(newBetManager);
  }

  function _setBetManager(address newBetManager)
  private {
    _betManager = newBetManager;
    emit SetBetManager(newBetManager);
  }

  function balanceOf(address account)
  public view override
  returns (uint256) {
    return balanceOf(account, false);
  }

  function balanceOf(address account, bool hasFixed)
  public view
  returns (uint256) {
    uint256 balance = super.balanceOf(account);
    if (hasFixed) return balance;
    uint256 fixedBalance = _fixedBalances[account];
    return balance > fixedBalance ? balance.unsafeSub(fixedBalance) : 0;
  }

  function transfer(address to, uint256 value)
  public override
  returns (bool) {
    address owner = _msgSender();
    bool isBet = to.isBet();
    bool isBetOption = to.isBetOption();

    if (isBet || isBetOption) {
      IBet bet;
      if (isBet) {
        bet = IBet(to);
      } else if (isBetOption) {
        bet = IBet(IBetOption(to).bet());
      }

      IBet.Status status = bet.status();
      if (status == IBet.Status.CONFIRMED || status == IBet.Status.CANCELLED) {
        bet.release();
        return true;
      }

      if (bet.vote() != address(this)) revert InvalidTarget(to);

      if (isBetOption && status == IBet.Status.DECIDING) {
        _decide(owner, to, value);
      } else if (status == IBet.Status.ARBITRATING) {
        _arbitrate(owner, to, value);
      } else {
        revert InvalidStatus(status);
      }
    } else {
      revert VoteNotTransferable();
    }

    return true;
  }

  function transferFrom(address, address, uint256)
  public pure override
  returns (bool) {
    revert VoteNotTransferable();
  }

  function _decide(address account, address target, uint256 value)
  private {
    (StakedRecord memory record,) = _getStakedRecords().find(account);
    if (record.account == account) {
      uint256 balance = balanceOf(account);
      if (balance < value) {
        revert VoteInsufficientAvailableBalance(account, balance, value);
      }
      _approve(account, target, value);
      IBetActionDecide(target).decide(account, value);
    } else {
      revert VoteConditionsNotMet(account);
    }
  }

  function _arbitrate(address account, address target, uint256 value)
  private {
    (StakedRecord memory record,) = _getStakedRecords().find(account, UnlockWaitingPeriod.WEEK12);
    if (record.account == account) {
      IBetActionArbitrate(target).arbitrate(account, value > 0 ? record.amount : 0);
    } else {
      revert VoteConditionsNotMet(account);
    }
  }

  function isAbleToDecide(address account)
  external view
  returns (bool) {
    (StakedRecord memory record,) = _getStakedRecords().find(account);
    return record.account == account;
  }

  function isAbleToArbitrate(address account)
  external view
  returns (bool) {
    (StakedRecord memory record,) = _getStakedRecords().find(account, UnlockWaitingPeriod.WEEK12);
    return record.account == account;
  }

  function fix(address account, uint256 value)
  external {
    address spender = _msgSender();
    if (!spender.isBet() && !spender.isBetOption()) revert UnauthorizedAccess(spender);

    _spendAllowance(account, spender, value);
    uint256 balance = balanceOf(account);
    if (balance < value) {
      revert VoteInsufficientAvailableBalance(account, balance, value);
    }
    _fixedAllowances[account][spender] = _fixedAllowances[account][spender].unsafeAdd(value);
    _fixedBalances[account] = _fixedBalances[account].unsafeAdd(value);
    emit Fixed(account, spender, value);
  }

  function unfix(address account, uint256 value)
  external {
    address spender = _msgSender();
    if (!spender.isBet() && !spender.isBetOption()) revert UnauthorizedAccess(spender);

    _unfix(account, spender, value);
    emit Unfixed(account, spender, value);
  }

  function _unfix(address account, address spender, uint256 value)
  private {
    uint256 allowance = _fixedAllowances[account][spender];
    if (allowance < value) {
      revert VoteInsufficientFixedAllowance(account, allowance, value);
    }
    _fixedAllowances[account][spender] = _fixedAllowances[account][spender].unsafeSub(value);
    _fixedBalances[account] = _fixedBalances[account].unsafeSub(value);
  }

  function confiscate(address account, uint256 value, address custodian)
  external {
    address spender = _msgSender();
    if (!spender.isBet() && !spender.isBetOption()) revert UnauthorizedAccess(spender);

    _unfix(account, spender, value);

    uint256 confiscatedTotalAmount = 0;
    uint256 confiscatedAmount = 0;
    uint256 remainingAmount = value;

    (confiscatedAmount, remainingAmount) = _confiscate(account, UnlockWaitingPeriod.WEEK, remainingAmount);
    confiscatedTotalAmount = confiscatedTotalAmount.unsafeAdd(confiscatedAmount);

    if (remainingAmount > 0) {
      (confiscatedAmount, remainingAmount) = _confiscate(account, UnlockWaitingPeriod.WEEK12, remainingAmount);
      confiscatedTotalAmount = confiscatedTotalAmount.unsafeAdd(confiscatedAmount);
    }

    if (remainingAmount > 0) revert VoteConfiscationFailed();

    _burn(account, confiscatedTotalAmount);
    custodian.receiveFromSelf(govToken(), confiscatedTotalAmount);
    emit Confiscated(account, spender, confiscatedTotalAmount);
  }

  function _confiscate(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private
  returns (uint256 confiscatedAmount, uint256 remainingAmount) {
    StakedRecord[] storage _stakedRecords = __stakedRecords();
    (,uint256 index) = _stakedRecords.find(account, unlockWaitingPeriod);
    if (index > 0) {
      StakedRecord storage record = _stakedRecords[index.unsafeDec()];
      if (record.amount >= amount) {
        confiscatedAmount = amount.unsafeAdd(record.subAmount(amount, stakeMinValue(), _stakedRecords));
        remainingAmount = 0;
      } else {
        confiscatedAmount = record.amount;
        remainingAmount = amount.unsafeSub(confiscatedAmount);
        record.removeFrom(_stakedRecords);
      }
    } else {
      confiscatedAmount = 0;
      remainingAmount = amount;
    }
  }
}
