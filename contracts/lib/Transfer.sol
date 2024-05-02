// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library TransferLib {
  error TransferFailed(uint256 amount);
  error Underpayment(uint256 paid, uint256 needed);

  function receiveFromSelf(address target, address token, uint256 amount)
  internal {
    if (token == address(0)) {
      if (amount == type(uint256).max) amount = address(this).balance;
      if (amount == 0) return;
      (bool success,) = payable(target).call{value: amount}("");
      if (!success) revert TransferFailed(amount);
    } else {
      IERC20 token_ = IERC20(token);
      if (amount == type(uint256).max) amount = token_.balanceOf(address(this));
      if (amount == 0) return;
      token_.transfer(target, amount);
    }
  }

  function transferToSelf(address target, address token, uint256 amount)
  internal {
    if (token == address(0)) {
      if (amount == type(uint256).max) amount = target.balance;
      if (msg.value < amount) revert Underpayment(msg.value, amount);
    } else {
      IERC20 token_ = IERC20(token);
      if (amount == type(uint256).max) amount = token_.balanceOf(target);
      if (amount == 0) return;
      uint256 value = token_.allowance(target, address(this));
      if (value < amount) revert Underpayment(value, amount);
      token_.transferFrom(target, address(this), amount);
    }
  }
}
