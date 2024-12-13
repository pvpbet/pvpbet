// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetActionDispute} from "./interface/IBetActionDispute.sol";
import {IBetActionWager} from "./interface/IBetActionWager.sol";
import {IBetChip} from "./interface/IBetChip.sol";
import {IBetOption} from "./interface/IBetOption.sol";
import {IErrors} from "./interface/IErrors.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {AddressLib} from "./lib/Address.sol";
import {MathLib} from "./lib/Math.sol";
import {TransferLib} from "./lib/Transfer.sol";
import "hardhat/console.sol";

contract BetChip is IBetChip, IErrors, IMetadata, ERC20 {
  function name()
  public view override(IMetadata, ERC20)
  returns (string memory) {
    return ERC20.name();
  }

  function version()
  public view
  returns (string memory) {
    return _version;
  }

  using MathLib for uint256;
  using AddressLib for address;
  using TransferLib for address;

  error ChipInsufficientBalance(address account, uint256 balance, uint256 value);
  error ChipNotExchangeable();
  error InvalidERC20Token();

  string private _version;
  address private immutable _token;
  uint8 private immutable _decimals;

  constructor(string memory version_, address token_)
  ERC20(
    _getTokenName(token_),
    _getTokenSymbol(token_)
  ) {
    _checkERC20Token(token_);
    _version = version_;
    _token = token_;
    _decimals = ERC20(token_).decimals();
  }

  function _getTokenName(address token_)
  private view
  returns (string memory) {
    if (token_.code.length == 0) revert InvalidERC20Token();
    try ERC20(token_).name() returns (string memory name_) {
      return string.concat("PVPBet Chip Wrapped ", name_);
    } catch {
      revert InvalidERC20Token();
    }
  }

  function _getTokenSymbol(address token_)
  private view
  returns (string memory) {
    if (token_.code.length == 0) revert InvalidERC20Token();
    try ERC20(token_).symbol() returns (string memory symbol) {
      return string.concat("cw", symbol);
    } catch {
      revert InvalidERC20Token();
    }
  }

  function _checkERC20Token(address token_)
  private {
    if (token_.code.length == 0) revert InvalidERC20Token();

    try ERC20(token_).balanceOf(address(this)) returns (uint256) {}
    catch {
      revert InvalidERC20Token();
    }

    try ERC20(token_).transfer(address(this), 0) returns (bool) {}
    catch {
      revert InvalidERC20Token();
    }

    try ERC20(token_).allowance(address(this), address(this)) returns (uint256) {}
    catch {
      revert InvalidERC20Token();
    }

    try ERC20(token_).transferFrom(address(this), address(this), 0) returns (bool) {}
    catch {
      revert InvalidERC20Token();
    }
  }

  function decimals()
  public view override
  returns (uint8) {
    return _decimals;
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

      address chip = bet.chip();
      if (chip != address(this)) revert InvalidChip(chip);

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

  function isBetChip()
  external pure
  returns (bool) {
    return true;
  }

  function transferBatch(address[] calldata tos, uint256[] calldata values)
  public
  returns (bool) {
    address owner = _msgSender();
    uint256 length = tos.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      _transfer(owner, tos[i], values[i]);
    }
    return true;
  }

  function token()
  external view
  returns (address) {
    return _token;
  }

  function deposit(uint256 value)
  external {
    address owner = _msgSender();
    _ensureValidAmount(value);
    _mintToAccount(owner, value);
    emit Deposited(owner, value);
  }

  function deposit(uint256 value, uint256 nonce, uint256 deadline, bytes calldata signature)
  external {
    address owner = _msgSender();
    _ensureValidAmount(value);
    _mintToAccount(owner, value, nonce, deadline, signature);
    emit Deposited(owner, value);
  }

  function withdraw(uint256 value)
  external {
    address owner = _msgSender();
    _ensureValidAmount(value);
    _burnFromAccount(owner, value);
    emit Withdrawn(owner, value);
  }

  function _ensureValidAmount(uint256 value)
  private pure {
    if (value == 0) revert InvalidAmount();
  }

  function _mintToAccount(address account, uint256 value)
  private {
    account.transferToContract(_token, value);
    _mint(account, value);
  }

  function _mintToAccount(address account, uint256 value, uint256 nonce, uint256 deadline, bytes calldata signature)
  private {
    account.transferToContract(_token, value, nonce, deadline, signature);
    _mint(account, value);
  }

  function _burnFromAccount(address account, uint256 value)
  private {
    _burn(account, value);
    account.transferFromContract(_token, value);
  }
}
