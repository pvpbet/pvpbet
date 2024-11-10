// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "../interface/IPermit2.sol";

library TransferLib {
  error TransferFailed(uint256 amount);
  error Underpayment(uint256 paid, uint256 needed);

  address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

  function transfer(
    address owner,
    address token,
    uint256 payment,
    uint256 refund
  )
  internal {
    if (payment > refund) {
      transferToContract(owner, token, payment - refund);
    } else if (payment < refund) {
      transferFromContract(owner, token, refund - payment);
    }
  }

  function transfer(
    address owner,
    address token,
    uint256 payment,
    uint256 refund,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  )
  internal {
    if (payment > refund) {
      transferToContract(owner, token, payment - refund, nonce, deadline, signature);
    } else if (payment < refund) {
      transferFromContract(owner, token, refund - payment);
    }
  }

  function transferFrom(
    address token,
    address from,
    address to,
    uint256 amount
  )
  internal {
    IERC20(token).transferFrom(from, to, amount);
  }

  function transferFrom(
    address token,
    address from,
    address to,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  )
  internal {
    IPermit2(PERMIT2).permitTransferFrom(
      IPermit2.PermitTransferFrom({
        permitted: IPermit2.TokenPermissions({
        token: token,
        amount: amount
      }),
        nonce: nonce,
        deadline: deadline
      }),
      IPermit2.SignatureTransferDetails({
        to: to,
        requestedAmount: amount
      }),
      from,
      signature
    );
  }

  function transferFromContract(address owner, address token, uint256 amount)
  internal
  returns (bool) {
    return transferFromContract(owner, token, amount, false);
  }

  function transferFromContract(address owner, address token, uint256 amount, bool ignoreFailure)
  internal
  returns (bool) {
    bool success = false;

    if (token == address(0)) {
      if (amount == type(uint256).max) amount = address(this).balance;
      if (amount == 0) return false;
      (success,) = payable(owner).call{value: amount}("");
    } else {
      IERC20 token_ = IERC20(token);
      if (amount == type(uint256).max) amount = token_.balanceOf(address(this));
      if (amount == 0) return false;
      success = token_.transfer(owner, amount);
    }

    if (!success) {
      if (!ignoreFailure) revert TransferFailed(amount);
      return false;
    }

    return true;
  }

  function transferToContract(address owner, address token, uint256 amount)
  internal
  returns (bool) {
    if (token == address(0)) {
      if (amount == type(uint256).max) amount = owner.balance;
      if (msg.value < amount) revert Underpayment(msg.value, amount);
    } else {
      IERC20 token_ = IERC20(token);
      if (amount == type(uint256).max) amount = token_.balanceOf(owner);
      if (amount == 0) return false;
      uint256 allowance = token_.allowance(owner, address(this));
      if (allowance < amount) revert Underpayment(allowance, amount);
      token_.transferFrom(owner, address(this), amount);
    }
    return true;
  }

  function transferToContract(
    address owner,
    address token,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  )
  internal
  returns (bool) {
    if (token == address(0)) {
      if (amount == type(uint256).max) amount = owner.balance;
      if (msg.value < amount) revert Underpayment(msg.value, amount);
    } else {
      IERC20 token_ = IERC20(token);
      if (amount == type(uint256).max) amount = token_.balanceOf(owner);
      if (amount == 0) return false;
      transferFrom(token, owner, address(this), amount, nonce, deadline, signature);
    }
    return true;
  }
}
