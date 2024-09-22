// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BetActionArbitrate} from "./base/BetActionArbitrate.sol";
import {BetActionDecide} from "./base/BetActionDecide.sol";
import {BetActionWager} from "./base/BetActionWager.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetOption} from "./interface/IBetOption.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {AddressLib} from "./lib/Address.sol";

contract BetOption is IBetOption, IMetadata, BetActionArbitrate, BetActionDecide, BetActionWager {
  function name()
  public pure virtual
  returns (string memory) {
    return "PVPBetOption";
  }

  function version()
  public view virtual
  returns (string memory) {
    return _version;
  }

  using AddressLib for address;

  error InvalidChip();

  address private immutable _bet;
  string private _description;
  string private _version;

  constructor (
    address bet_,
    string memory description_,
    string memory version_
  ) {
    _bet = bet_;
    _description = description_;
    _version = version_;
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

  function bet()
  public view override(IBetOption, BetActionArbitrate, BetActionDecide, BetActionWager)
  returns (address) {
    return _bet;
  }

  function chip()
  public view override(IBetOption, BetActionWager)
  returns (address) {
    return IBet(_bet).chip();
  }

  function chipMinValue()
  public view override(IBetOption, BetActionWager)
  returns (uint256) {
    return IBet(_bet).chipMinValue();
  }

  function vote()
  public view override(IBetOption, BetActionArbitrate, BetActionDecide)
  returns (address) {
    return IBet(_bet).vote();
  }

  function voteMinValue()
  public view override(IBetOption, BetActionArbitrate, BetActionDecide)
  returns (uint256) {
    return IBet(_bet).voteMinValue();
  }

  function description()
  external view
  returns (string memory) {
    return _description;
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

    if (bet_.chip() != address(0)) revert InvalidChip();
    if (AddressLib.isContractSender()) revert CannotReceive();
    wager(msg.value);
  }
}
