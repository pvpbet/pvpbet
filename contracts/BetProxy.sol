// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBetActionDispute} from "./interface/IBetActionDispute.sol";
import {IBetActionWager} from "./interface/IBetActionWager.sol";

contract BetProxy {
  function wager(address target, uint256 amount) external {
    IBetActionWager(target).wager(msg.sender, amount);
  }

  function wager(
    address target,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    IBetActionWager(target).wager(msg.sender, amount, nonce, deadline, signature);
  }

  function dispute(address target, uint256 amount) external {
    IBetActionDispute(target).dispute(msg.sender, amount);
  }

  function dispute(
    address target,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    IBetActionDispute(target).dispute(msg.sender, amount, nonce, deadline, signature);
  }
}
