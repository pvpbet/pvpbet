// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReceivable {
  event Received(address indexed sender, uint256 value);

  receive() external payable;
}
