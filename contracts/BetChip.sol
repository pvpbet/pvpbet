// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetActionDispute} from "./interface/IBetActionDispute.sol";
import {IBetActionWager} from "./interface/IBetActionWager.sol";
import {IBetChip} from "./interface/IBetChip.sol";
import {IBetOption} from "./interface/IBetOption.sol";
import {IErrors} from "./interface/IErrors.sol";
import {AddressLib} from "./lib/Address.sol";
import {MathLib} from "./lib/Math.sol";
import {TransferLib} from "./lib/Transfer.sol";

contract BetChip is IBetChip, IErrors, ERC20 {
  using MathLib for uint256;
  using AddressLib for address;
  using TransferLib for address;

  error ChipInsufficientBalance(address account, uint256 balance, uint256 value);
  error ChipNotExchangeable();
  error InvalidChip();

  address private immutable _currency;

  constructor(address currency_) ERC20("PVPBetChip", "cPVPB") {
    _currency = currency_;
  }

  function decimals()
  public view override
  returns (uint8) {
    return _currency.decimals();
  }

  function transfer(address to, uint256 value)
  public override
  returns (bool) {
    address owner = _msgSender();
    bool isBet = to.isBet();
    bool isBetOption = to.isBetOption();

    if (to == address(this)) {
      _burnFromAccount(owner, value);
    } else if (isBet || isBetOption) {
      IBet bet;
      if (isBet) {
        bet = IBet(to);
      } else if (isBetOption) {
        bet = IBet(IBetOption(to).bet());
      }

      IBet.Status status = bet.status();
      if (status >= IBet.Status.CONFIRMED) {
        if (owner.isBetOption()) {
          _transfer(owner, to, value);
          return true;
        }
        if (status == IBet.Status.CLOSED) revert CannotReceive();
        else if (status == IBet.Status.CONFIRMED || status == IBet.Status.CANCELLED) {
          if (value > 0) revert CannotReceive();
          bet.release();
          return true;
        }
      }

      if (bet.chip() != address(this)) revert InvalidChip();

      uint256 balance = balanceOf(owner);
      if (balance < value) revert ChipInsufficientBalance(owner, balance, value);

      if (isBet) {
        _approve(owner, to, value);
        IBetActionDispute(to).dispute(owner, value);
      } else if (isBetOption) {
        _approve(owner, to, value);
        IBetActionWager(to).wager(owner, value);
      }
    } else {
      _transfer(owner, to, value);
    }

    return true;
  }

  function currency()
  external view
  returns (address) {
    return _currency;
  }

  function deposit(uint256 amount)
  external {
    address sender = _msgSender();
    _ensureValidAmount(amount);
    _mintToAccount(sender, amount);
    emit Deposited(sender, amount);
  }

  function withdraw(uint256 amount)
  external {
    address sender = _msgSender();
    _ensureValidAmount(amount);
    _burnFromAccount(sender, amount);
    emit Withdrawn(sender, amount);
  }

  function _ensureValidAmount(uint256 amount)
  private pure {
    if (amount == 0) revert InvalidAmount();
  }

  function _mintToAccount(address account, uint256 amount)
  private {
    account.transferToContract(_currency, amount);
    _mint(account, amount);
  }

  function _burnFromAccount(address account, uint256 amount)
  private {
    _burn(account, amount);
    account.transferFromContract(_currency, amount);
  }
}
