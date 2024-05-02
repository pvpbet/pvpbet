// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TransferLib} from "../lib/Transfer.sol";

contract AttackContract {
  using TransferLib for address;

  error IsAttacker();

  constructor(address bet) payable {
    bet.receiveFromSelf(address(0), msg.value);
  }

  receive() external payable {
    revert IsAttacker();
  }
}
