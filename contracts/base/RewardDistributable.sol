// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRewardDistributable} from "../interface/IRewardDistributable.sol";
import {MathLib} from "../lib/Math.sol";
import {TransferLib} from "../lib/Transfer.sol";

abstract contract RewardDistributable is IRewardDistributable {
  using MathLib for uint256;
  using TransferLib for address;

  error NoClaimableRewards();

  mapping(address account => mapping(address token => uint256 amount)) private _claimedRewards;
  mapping(address account => mapping(address token => uint256 amount)) private _unclaimedRewards;

  function _rewardDistribute(address token, uint256 amount)
  internal virtual;

  function _rewardDistributeTo(address account, address token, uint256 amount)
  internal {
    _unclaimedRewards[account][token] = _unclaimedRewards[account][token].unsafeAdd(amount);
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
    sender.transferToContract(token, amount);
    _rewardDistribute(token, amount);
    emit Distributed(sender, token, amount);
  }

  function claimedRewards(address account)
  external view
  returns (uint256) {
    return _claimedRewards[account][address(0)];
  }

  function claimedRewards(address account, address token)
  external view
  returns (uint256) {
    return _claimedRewards[account][token];
  }

  function unclaimedRewards(address account)
  external view
  returns (uint256) {
    return _unclaimedRewards[account][address(0)];
  }

  function unclaimedRewards(address account, address token)
  external view
  returns (uint256) {
    return _unclaimedRewards[account][token];
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
    uint256 amount = _unclaimedRewards[account][token];
    if (amount == 0) revert NoClaimableRewards();
    _unclaimedRewards[account][token] = 0;
    _claimedRewards[account][token] = _claimedRewards[account][token].unsafeAdd(amount);
    account.transferFromContract(token, amount);
    emit Claimed(account, token, amount);
  }
}
