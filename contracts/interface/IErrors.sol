// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IErrors {
  error CannotReceive();
  error InvalidAmount();
  error UnauthorizedAccess(address sender);
}
