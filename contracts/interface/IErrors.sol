// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IErrors {
  error CannotReceive();
  error InvalidChip(address token);
  error InvalidAmount();
  error InvalidToken();
  error UnauthorizedAccess(address sender);
}
