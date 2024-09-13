// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetVotingEscrow} from "../interface/IBetVotingEscrow.sol";
import {AddressLib} from "../lib/Address.sol";
import {TransferLib} from "../lib/Transfer.sol";

contract TestBetOption {
  using TransferLib for address;

  address public bet;
  bool public wagered;
  bool public decided;
  bool public arbitrated;

  constructor(address bet_) {
    bet = bet_;
  }

  function isBetOption()
  external pure
  returns (bool) {
    return true;
  }

  function chip()
  public view
  returns (address) {
    return IBet(bet).chip();
  }

  function vote()
  public view
  returns (address) {
    return IBet(bet).vote();
  }

  function wager(address player, uint256 amount)
  external {
    player.transferToContract(chip(), amount);
    wagered = true;
  }

  function decide(address decider, uint256 amount)
  external {
    IBetVotingEscrow(vote()).fix(decider, amount);
    decided = true;
  }

  function arbitrate(address, uint256)
  external {
    arbitrated = true;
  }

  function functionCall(address target, bytes memory data)
  external
  returns (bytes memory) {
    return AddressLib.functionCallWithValue(target, data, 0);
  }
}
