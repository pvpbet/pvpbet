// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IReceivable} from "../interface/IReceivable.sol";

abstract contract Receivable is IReceivable {
  receive() external payable virtual {
    emit Received(msg.sender, msg.value);
  }
}
