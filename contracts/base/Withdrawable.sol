// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IWithdrawable} from "../interface/IWithdrawable.sol";
import {TransferLib} from "../lib/Transfer.sol";

abstract contract Withdrawable is IWithdrawable {
  using TransferLib for address;

  /**
   * @dev Function that should revert when `msg.sender` is not authorized to withdraw.
   *
   * ```solidity
   * function _authorizeWithdraw(address) internal override(Withdrawable) onlyOwner {}
   * ```
   */
  function _authorizeWithdraw(address sender)
  internal virtual;

  function withdraw()
  public virtual {
    _authorizeWithdraw(msg.sender);
    _withdraw(address(0), type(uint256).max);
  }

  function withdraw(uint256 amount)
  public virtual {
    _authorizeWithdraw(msg.sender);
    _withdraw(address(0), amount);
  }

  function withdrawERC20(address token)
  public virtual {
    _authorizeWithdraw(msg.sender);
    _withdraw(token, type(uint256).max);
  }

  function withdrawERC20(address token, uint256 amount)
  public virtual {
    _authorizeWithdraw(msg.sender);
    _withdraw(token, amount);
  }

  function _withdraw(address token, uint256 amount)
  internal {
    address account = msg.sender;
    account.receiveFromSelf(token, amount);

    if (token == address(0)) {
      emit Withdrawn(account, amount);
    } else {
      emit WithdrawnERC20(account, token, amount);
    }
  }
}
