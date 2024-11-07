// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "./interface/IPermit2.sol";
import {IUniversalRouter} from "./interface/IUniversalRouter.sol";
import {TransferLib} from "./lib/Transfer.sol";

contract UniswapRouter {
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
      IERC20(token).transferFrom(msg.sender, swapRouter, amount);
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
      IPermit2(TransferLib.PERMIT2).permitTransferFrom(
        IPermit2.PermitTransferFrom({
          permitted: IPermit2.TokenPermissions({
            token: token,
            amount: amount
          }),
          nonce: nonce,
          deadline: deadline
        }),
        IPermit2.SignatureTransferDetails({
          to: swapRouter,
          requestedAmount: amount
        }),
        msg.sender,
        signature
      );
    }
    IUniversalRouter(swapRouter).execute(commands, inputs);
  }
}
