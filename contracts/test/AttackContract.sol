// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {TransferLib} from "../lib/Transfer.sol";

contract AttackContract {
  using TransferLib for address;

  error IsAttacker();

  constructor(address bet) payable {
    if (msg.value > 0) {
      bet.transferFromContract(address(0), msg.value);
    }
  }

  function functionCall(address target, bytes calldata data)
  external
  returns (bytes memory) {
    return Address.functionCallWithValue(target, data, 0);
  }

  receive() external payable {
    revert IsAttacker();
  }
}
