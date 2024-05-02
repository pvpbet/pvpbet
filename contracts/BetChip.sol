// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Receivable} from "./base/Receivable.sol";
import {Upgradeable} from "./base/Upgradeable.sol";
import {Withdrawable} from "./base/Withdrawable.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetChip} from "./interface/IBetChip.sol";
import {IBetOption} from "./interface/IBetOption.sol";
import {IBetActionDispute} from "./interface/IBetActionDispute.sol";
import {IBetActionWager} from "./interface/IBetActionWager.sol";
import {MathLib} from "./lib/Math.sol";
import {Array2DLib} from "./lib/Array2D.sol";
import {AddressLib} from "./lib/Address.sol";
import {TransferLib} from "./lib/Transfer.sol";

contract BetChip is IBetChip, ERC20Upgradeable, Upgradeable, Receivable, Withdrawable {
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
  using Array2DLib for uint256[][];
  using AddressLib for address;
  using TransferLib for address;

  error AmountMustBeGreaterThanZero();
  error QuantityMustBeGreaterThanZero();
  error CannotReceive();
  error ChipInsufficientBalance(address account, uint256 balance, uint256 value);
  error ChipNotExchangeable();
  error InvalidArrayLength(uint256 currenciesLength, uint256 ratesLength);
  error InvalidChip();
  error InvalidCurrency(address currency);

  address[] private _currencies;
  uint256[] private _rates;

  function initialize(address[] calldata initialCurrencies, uint256[] calldata initialRates)
  public
  initializer {
    Upgradeable.initialize();
    __ERC20_init("PVPBetChip", "cPVPB");
    _setCurrenciesAndRates(initialCurrencies, initialRates);
  }

  function _authorizeWithdraw(address sender)
  internal view override(Withdrawable) onlyOwner {}

  function currenciesAndRates()
  external view
  returns (address[] memory, uint256[] memory) {
    return (_currencies, _rates);
  }

  function setCurrenciesAndRates(address[] calldata newCurrencies, uint256[] calldata newRates)
  external
  onlyOwner {
    _setCurrenciesAndRates(newCurrencies, newRates);
  }

  function _setCurrenciesAndRates(address[] calldata newCurrencies, uint256[] calldata newRates)
  private {
    if (newCurrencies.length != newRates.length) {
      revert InvalidArrayLength(newCurrencies.length, newRates.length);
    }
    _currencies = newCurrencies;
    _rates = newRates;
    emit SetCurrenciesAndRates(newCurrencies, newRates);
  }

  function buy(address currency, uint256 quantity)
  public payable {
    _ensureValidQuantity(quantity);
    uint256 amount = getTokenAmount(currency, quantity);
    _ensureValidAmount(amount);
    _mintToAccount(msg.sender, quantity, currency, amount);
  }

  function sell(address currency, uint256 quantity)
  public {
    _ensureValidQuantity(quantity);
    uint256 amount = getTokenAmount(currency, quantity);
    _ensureValidAmount(amount);
    address[] memory currencies = new address[](1);
    uint256[] memory amounts = new uint256[](1);
    currencies[0] = currency;
    amounts[0] = amount;
    _burnFromAccount(msg.sender, quantity, currencies, amounts);
  }

  function deposit(address currency, uint256 amount)
  public payable {
    _ensureValidAmount(amount);
    uint256 quantity = getTokenQuantity(currency, amount);
    _ensureValidQuantity(quantity);
    _mintToAccount(msg.sender, quantity, currency, amount);
  }

  function withdraw(address currency, uint256 amount)
  public {
    _ensureValidAmount(amount);
    uint256 quantity = getTokenQuantity(currency, amount);
    _ensureValidQuantity(quantity);
    address[] memory currencies = new address[](1);
    uint256[] memory amounts = new uint256[](1);
    currencies[0] = currency;
    amounts[0] = amount;
    _burnFromAccount(msg.sender, quantity, currencies, amounts);
  }

  function getTokenAmount(address currency, uint256 quantity)
  public view
  returns (uint256) {
    uint256 rate = _getCurrencyRate(currency);
    return quantity / rate;
  }

  function getTokenQuantity(address currency, uint256 amount)
  public view
  returns (uint256) {
    uint256 rate = _getCurrencyRate(currency);
    return amount * rate;
  }

  function _getCurrencyRate(address currency)
  private view
  returns (uint256) {
    uint256 length = _currencies.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (_currencies[i] == currency) {
        if (_rates[i] == 0) revert InvalidCurrency(currency);
        return _rates[i];
      }
    }
    revert InvalidCurrency(currency);
  }

  function transfer(address to, uint256 value)
  public override
  returns (bool) {
    address owner = _msgSender();
    _transferFrom(owner, to, value);
    return true;
  }

  function transferFrom(address from, address to, uint256 value)
  public override
  returns (bool) {
    address spender = _msgSender();
    _spendAllowance(from, spender, value);
    _transferFrom(from, to, value);
    return true;
  }

  function _transferFrom(address from, address to, uint256 value)
  private {
    address sender = _msgSender();
    bool isBet = to.isBet();
    bool isBetOption = to.isBetOption();

    if (to == address(this)) {
      _burnQuantity(from, value);
    } else if (!sender.isBet() && !sender.isBetOption() && (isBet || isBetOption)) {
      IBet bet;
      if (isBet) {
        bet = IBet(to);
      } else if (isBetOption) {
        bet = IBet(IBetOption(to).bet());
      }

      IBet.Status status = bet.status();
      if (status == IBet.Status.CLOSED) revert CannotReceive();
      if (status == IBet.Status.CONFIRMED || status == IBet.Status.CANCELLED) {
        if (value > 0) revert CannotReceive();
        bet.release();
        return;
      }

      if (bet.chip() != address(this)) revert InvalidChip();

      uint256 balance = balanceOf(from);
      if (balance < value) revert ChipInsufficientBalance(from, balance, value);

      if (isBet) {
        _approve(from, to, value);
        IBetActionDispute(to).dispute(from, value);
      } else if (isBetOption) {
        _approve(from, to, value);
        IBetActionWager(to).wager(from, value);
      }
    } else {
      _transfer(from, to, value);
    }
  }

  function _ensureValidAmount(uint256 amount)
  private pure {
    if (amount == 0) revert AmountMustBeGreaterThanZero();
  }

  function _ensureValidQuantity(uint256 quantity)
  private pure {
    if (quantity == 0) revert QuantityMustBeGreaterThanZero();
  }

  function _mintToAccount(address account, uint256 quantity, address currency, uint256 amount)
  private {
    account.transferToSelf(currency, amount);
    _mint(account, quantity);
    emit Mint(account, quantity, currency, amount);
  }

  function _burnFromAccount(address account, uint256 quantity, address[] memory currencies, uint256[] memory amounts)
  private {
    _burn(account, quantity);
    uint256 length = currencies.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (amounts[i] == 0) continue;
      account.receiveFromSelf(currencies[i], amounts[i]);
    }
    emit Burn(account, quantity, currencies, amounts);
  }

  function _burnQuantity(address account, uint256 quantity)
  private {
    _ensureValidQuantity(quantity);

    uint256 length = _currencies.length;

    uint256[][] memory arr2d = new uint256[][](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address currency = _currencies[i];
      arr2d[i] = new uint256[](3);
      arr2d[i][0] = i;
      uint256 balance = currency == address(0) ? address(this).balance : IERC20(currency).balanceOf(address(this));
      if (balance == 0) continue;
      arr2d[i][1] = balance;
      arr2d[i][2] = getTokenQuantity(currency, balance);
    }

    arr2d.sortBy(2);

    address[] memory currencies = new address[](length);
    uint256[] memory amounts = new uint256[](length);
    uint256 remainingQuantity = quantity;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address currency = _currencies[arr2d[i][0]];
      uint256 balance = arr2d[i][1];
      uint256 quantityOfBalance = arr2d[i][2];
      if (quantityOfBalance == 0) continue;
      uint256 amount = 0;
      if (remainingQuantity >= quantityOfBalance) {
        remainingQuantity = remainingQuantity.unsafeSub(quantityOfBalance);
        amount = balance;
      } else {
        amount = getTokenAmount(currency, remainingQuantity);
        remainingQuantity = 0;
      }
      currencies[i] = currency;
      amounts[i] = amount;
      if (remainingQuantity == 0) {
        _burnFromAccount(account, quantity, currencies, amounts);
        return;
      }
    }

    revert ChipNotExchangeable();
  }
}
