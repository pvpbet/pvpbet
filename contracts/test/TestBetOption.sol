// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IVotingEscrow} from "../interface/IVotingEscrow.sol";
import {AddressLib} from "../lib/Address.sol";
import {TransferLib} from "../lib/Transfer.sol";

contract TestBetOption {
  using TransferLib for address;

  address public bet;
  bool public wagered;
  bool public verified;
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

  function verify(address verifier, uint256 amount)
  external {
    IVotingEscrow(vote()).fix(verifier, amount);
    verified = true;
  }

  function arbitrate(address, uint256)
  external {
    arbitrated = true;
  }

  function functionCall(address target, bytes calldata data)
  external
  returns (bytes memory) {
    return AddressLib.functionCallWithValue(target, data, 0);
  }
}
