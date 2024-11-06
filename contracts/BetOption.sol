// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BetActionArbitrate} from "./base/BetActionArbitrate.sol";
import {BetActionDecide} from "./base/BetActionDecide.sol";
import {BetActionWager} from "./base/BetActionWager.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetOption} from "./interface/IBetOption.sol";
import {IErrors} from "./interface/IErrors.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {AddressLib} from "./lib/Address.sol";

contract BetOption is IBetOption, IErrors, IMetadata, BetActionArbitrate, BetActionDecide, BetActionWager {
  function name()
  public pure
  returns (string memory) {
    return "PVPBetOption";
  }

  function version()
  public view
  returns (string memory) {
    return _version;
  }

  using AddressLib for address;

  error InvalidInitialization();

  string private _version;
  string private _description;
  IBet.BetConfig private _config;
  address private _bet;
  address private _chip;
  address private _vote;
  bool private _initialized;

  function initialize(
    string calldata version_,
    string calldata description_,
    IBet.BetConfig calldata config_,
    address bet_,
    address chip_,
    address vote_
  )
  public {
    if (_initialized) revert InvalidInitialization();
    _initialized = true;
    _version = version_;
    _description = description_;
    _config = config_;
    _bet = bet_;
    _chip = chip_;
    _vote = vote_;
  }

  modifier onlyBet() override(BetActionDecide, BetActionWager) {
    if (msg.sender != bet()) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  modifier onlyVote() override(BetActionArbitrate, BetActionDecide) {
    if (msg.sender != vote()) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function isBetOption()
  external pure
  returns (bool) {
    return true;
  }

  function description()
  external view
  returns (string memory) {
    return _description;
  }

  function bet()
  public view override(IBetOption, BetActionArbitrate, BetActionDecide, BetActionWager)
  returns (address) {
    return _bet;
  }

  function chip()
  public view override(IBetOption, BetActionWager)
  returns (address) {
    return _chip;
  }

  function vote()
  public view override(IBetOption, BetActionArbitrate, BetActionDecide)
  returns (address) {
    return _vote;
  }

  function chipMinValue()
  public view override(IBetOption, BetActionWager)
  returns (uint256) {
    return _config.chipMinValue;
  }

  function voteMinValue()
  public view override(IBetOption, BetActionArbitrate, BetActionDecide)
  returns (uint256) {
    return _config.voteMinValue;
  }

  receive() external payable {
    IBet bet_ = IBet(_bet);
    IBet.Status status = bet_.status();
    if (status == IBet.Status.CLOSED) revert CannotReceive();
    else if (status == IBet.Status.CONFIRMED || status == IBet.Status.CANCELLED) {
      if (msg.value > 0) revert CannotReceive();
      bet_.release();
      return;
    }

    if (_chip != address(0)) revert InvalidChip(_chip);
    if (AddressLib.isContractSender()) revert CannotReceive();
    wager(msg.value);
  }
}
