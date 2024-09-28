// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BetActionArbitrate} from "./base/BetActionArbitrate.sol";
import {BetActionDecide} from "./base/BetActionDecide.sol";
import {BetActionWager} from "./base/BetActionWager.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetOption} from "./interface/IBetOption.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {AddressLib} from "./lib/Address.sol";

contract BetOption is IBetOption, Initializable, IMetadata, BetActionArbitrate, BetActionDecide, BetActionWager {
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

  error InvalidChip();

  string private _version;
  string private _description;
  address private _bet;
  address private _chip;
  address private _vote;
  uint256 private _chipPerQuantity;
  uint256 private _votePerQuantity;

  function initialize(
    string memory version_,
    string memory description_,
    address bet_,
    address chip_,
    address vote_,
    uint256 chipPerQuantity,
    uint256 votePerQuantity
  )
  public
  initializer {
    _version = version_;
    _description = description_;
    _bet = bet_;
    _chip = chip_;
    _vote = vote_;
    _chipPerQuantity = chipPerQuantity;
    _votePerQuantity = votePerQuantity;
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
    if (_chip == address(0)) {
      return 0.001 ether;
    } else {
      return _chipPerQuantity;
    }
  }

  function voteMinValue()
  public view override(IBetOption, BetActionArbitrate, BetActionDecide)
  returns (uint256) {
    return _votePerQuantity;
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

    if (_chip != address(0)) revert InvalidChip();
    if (AddressLib.isContractSender()) revert CannotReceive();
    wager(msg.value);
  }
}
