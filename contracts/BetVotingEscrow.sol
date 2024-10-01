// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Receivable} from "./base/Receivable.sol";
import {Upgradeable} from "./base/Upgradeable.sol";
import {UseGovTokenStaking} from "./base/UseGovTokenStaking.sol";
import {Withdrawable} from "./base/Withdrawable.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetActionArbitrate} from "./interface/IBetActionArbitrate.sol";
import {IBetActionDecide} from "./interface/IBetActionDecide.sol";
import {IBetOption} from "./interface/IBetOption.sol";
import {IBetVotingEscrow} from "./interface/IBetVotingEscrow.sol";
import {IErrors} from "./interface/IErrors.sol";
import {IGovTokenStaking} from "./interface/IGovTokenStaking.sol";
import {AddressLib} from "./lib/Address.sol";
import {MathLib} from "./lib/Math.sol";

contract BetVotingEscrow is IBetVotingEscrow, IErrors, ERC20Upgradeable, Upgradeable, Receivable, Withdrawable, UseGovTokenStaking {
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

  error InvalidStatus(IBet.Status status);
  error InvalidTarget(address target);
  error VoteInsufficientAvailableBalance(address account, uint256 balance, uint256 value);
  error VoteInsufficientFixedAllowance(address account, uint256 allowance, uint256 value);
  error VoteNotTransferable();
  error VotingConditionsNotMet(address account);

  mapping(address account => uint256 value) private _fixedBalances;
  mapping(address account => mapping(address spender => uint256 value)) private _fixedAllowances;

  function initialize()
  public override(Upgradeable)
  initializer {
    Upgradeable.initialize();
    __ERC20_init("PVPBetVotingEscrow", "vePVPB");
  }

  function _authorizeWithdraw(address sender)
  internal view override(Withdrawable) onlyOwner {}

  function _authorizeUpdateGovTokenStaking(address sender)
  internal view override(UseGovTokenStaking) onlyOwner {}

  function mint(address account, uint256 value)
  external
  onlyGovTokenStaking {
    _mint(account, value);
  }

  function burn(address account, uint256 value)
  external
  onlyGovTokenStaking {
    uint256 balance = balanceOf(account);
    if (balance < value) revert VoteInsufficientAvailableBalance(account, balance, value);
    _burn(account, value);
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
      if (status == IBet.Status.CLOSED) revert CannotReceive();
      else if (status == IBet.Status.CONFIRMED || status == IBet.Status.CANCELLED) {
        if (value > 0) revert CannotReceive();
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
    uint256 stakedAmount = IGovTokenStaking(govTokenStaking()).stakedAmount(account);
    if (stakedAmount > 0) {
      uint256 balance = balanceOf(account);
      if (balance < value) {
        revert VoteInsufficientAvailableBalance(account, balance, value);
      }
      _approve(account, target, value);
      IBetActionDecide(target).decide(account, value);
    } else {
      revert VotingConditionsNotMet(account);
    }
  }

  function _arbitrate(address account, address target, uint256 value)
  private {
    uint256 stakedAmount = IGovTokenStaking(govTokenStaking()).stakedAmount(account, IGovTokenStaking.UnlockWaitingPeriod.WEEK12);
    if (stakedAmount > 0) {
      IBetActionArbitrate(target).arbitrate(account, value > 0 ? stakedAmount : 0);
    } else {
      revert VotingConditionsNotMet(account);
    }
  }

  function isAbleToDecide(address account)
  public view
  returns (bool) {
    uint256 stakedAmount = IGovTokenStaking(govTokenStaking()).stakedAmount(account);
    return stakedAmount > 0;
  }

  function isAbleToArbitrate(address account)
  public view
  returns (bool) {
    uint256 stakedAmount = IGovTokenStaking(govTokenStaking()).stakedAmount(account, IGovTokenStaking.UnlockWaitingPeriod.WEEK12);
    return stakedAmount > 0;
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
    emit Fixed(spender, account, value);
  }

  function _unfix(address spender, address account, uint256 value)
  private {
    uint256 allowance = _fixedAllowances[account][spender];
    if (allowance < value) {
      revert VoteInsufficientFixedAllowance(account, allowance, value);
    }
    _fixedAllowances[account][spender] = _fixedAllowances[account][spender].unsafeSub(value);
    _fixedBalances[account] = _fixedBalances[account].unsafeSub(value);
  }

  function unfix(address account, uint256 value)
  external {
    address spender = _msgSender();
    if (!spender.isBet() && !spender.isBetOption()) revert UnauthorizedAccess(spender);

    _unfix(spender, account, value);
    emit Unfixed(spender, account, value);
  }

  function unfixBatch(address[] calldata accounts, uint256[] calldata values)
  external {
    address spender = _msgSender();
    if (!spender.isBet() && !spender.isBetOption()) revert UnauthorizedAccess(spender);

    uint256 length = accounts.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      _unfix(spender, accounts[i], values[i]);
    }
    emit UnfixedBatch(spender, accounts, values);
  }

  function confiscate(address account, uint256 value, address custodian)
  external {
    address spender = _msgSender();
    if (!spender.isBet() && !spender.isBetOption()) revert UnauthorizedAccess(spender);

    _unfix(spender, account, value);
    _burn(account, value);
    IGovTokenStaking(govTokenStaking()).deductStakedAmountAndTransfer(account, value, custodian);
    emit Confiscated(spender, account, value);
  }

  function confiscateBatch(address[] calldata accounts, uint256[] calldata values, address custodian)
  external {
    address spender = _msgSender();
    if (!spender.isBet() && !spender.isBetOption()) revert UnauthorizedAccess(spender);

    uint256 length = accounts.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address account = accounts[i];
      uint256 value = values[i];
      _unfix(spender, account, value);
      _burn(account, value);
    }
    IGovTokenStaking(govTokenStaking()).batchDeductStakedAmountAndTransfer(accounts, values, custodian);
    emit ConfiscatedBatch(spender, accounts, values);
  }
}
