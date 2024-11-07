// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniversalRouter {
  // Reference https://github.com/Uniswap/universal-router

  function execute(bytes calldata commands, bytes[] calldata inputs) external payable;
}
