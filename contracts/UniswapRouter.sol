// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniversalRouter} from "./interface/IUniversalRouter.sol";
import {TransferLib} from "./lib/Transfer.sol";

contract UniswapRouter {
  using TransferLib for address;

  address public immutable swapRouter;

  constructor(address swapRouter_) {
    swapRouter = swapRouter_;
  }

  function execute(
    bytes calldata commands,
    bytes[] calldata inputs,
    address token,
    uint256 amount
  )
  external payable {
    if (amount > 0) {
      token.transferFrom(msg.sender, swapRouter, amount);
    }
    IUniversalRouter(swapRouter).execute(commands, inputs);
  }

  function execute(
    bytes calldata commands,
    bytes[] calldata inputs,
    address token,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  )
  external payable {
    if (amount > 0) {
      token.transferFrom(msg.sender, swapRouter, amount, nonce, deadline, signature);
    }
    IUniversalRouter(swapRouter).execute(commands, inputs);
  }
}
