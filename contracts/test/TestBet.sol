// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {AddressLib} from "../lib/Address.sol";
import {TransferLib} from "../lib/Transfer.sol";

contract TestBet {
  using TransferLib for address;

  address public chip;
  address public vote;
  IBet.Status public status;
  bool public disputed;
  bool public arbitrated;

  constructor(IBet.Status status_, address chip_, address vote_) {
    status = status_;
    chip = chip_;
    vote = vote_;
  }

  function isBet()
  external pure
  returns (bool) {
    return true;
  }

  function dispute(address disputer, uint256 amount)
  external {
    disputer.transferToSelf(chip, amount);
    disputed = true;
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
