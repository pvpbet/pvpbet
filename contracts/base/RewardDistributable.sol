// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRewardDistributable} from "../interface/IRewardDistributable.sol";
import {MathLib} from "../lib/Math.sol";
import {TransferLib} from "../lib/Transfer.sol";

abstract contract RewardDistributable is IRewardDistributable {
  using MathLib for uint256;
  using TransferLib for address;

  error NoClaimableRewards();

  mapping(address account => mapping(address token => uint256 amount)) private _rewards;
  mapping(address account => mapping(address token => uint256 amount)) private _claimableRewards;

  function _rewardDistribute(address token, uint256 amount)
  internal virtual;

  function _rewardDistributeTo(address account, address token, uint256 amount)
  internal {
    _rewards[account][token] = _rewards[account][token].unsafeAdd(amount);
    _claimableRewards[account][token] = _claimableRewards[account][token].unsafeAdd(amount);
  }

  function distribute()
  external payable virtual {
    _distribute(address(0), msg.value);
  }

  function distribute(address token, uint256 amount)
  external virtual {
    _distribute(token, amount);
  }

  function _distribute(address token, uint256 amount)
  internal {
    address sender = msg.sender;
    sender.transferToSelf(token, amount);
    _rewardDistribute(token, amount);
    emit Distributed(sender, token, amount);
  }

  function rewards(address account)
  external view
  returns (uint256) {
    return _rewards[account][address(0)];
  }

  function rewards(address account, address token)
  external view
  returns (uint256) {
    return _rewards[account][token];
  }

  function claimableRewards(address account)
  external view
  returns (uint256) {
    return _claimableRewards[account][address(0)];
  }

  function claimableRewards(address account, address token)
  external view
  returns (uint256) {
    return _claimableRewards[account][token];
  }

  function claim()
  external virtual {
    _claim(address(0));
  }

  function claim(address token)
  external virtual {
    _claim(token);
  }

  function _claim(address token)
  internal {
    address account = msg.sender;
    uint256 amount = _claimableRewards[account][token];
    if (amount == 0) revert NoClaimableRewards();
    _claimableRewards[account][token] = 0;
    account.receiveFromSelf(token, amount);
    emit Claimed(account, token, amount);
  }
}
