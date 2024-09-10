// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AddressLib} from "../lib/Address.sol";
import {TransferLib} from "../lib/Transfer.sol";

contract AttackContract {
  using TransferLib for address;

  error IsAttacker();

  constructor(address bet) payable {
    if (msg.value > 0) {
      bet.receiveFromSelf(address(0), msg.value);
    }
  }

  function functionCall(address target, bytes memory data)
  external
  returns (bytes memory) {
    return AddressLib.functionCallWithValue(target, data, 0);
  }

  receive() external payable {
    revert IsAttacker();
  }
}
