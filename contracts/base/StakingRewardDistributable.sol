// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStakingRewardDistributable} from "../interface/IStakingRewardDistributable.sol";
import {MathLib} from "../lib/Math.sol";
import {TransferLib} from "../lib/Transfer.sol";
import {StakedRecord, StakedRecordLib, StakedRecordArrayLib} from "../lib/StakedRecord.sol";

abstract contract StakingRewardDistributable is IStakingRewardDistributable {
  using MathLib for uint256;
  using TransferLib for address;
  using StakedRecordLib for StakedRecord;
  using StakedRecordArrayLib for StakedRecord[];

  error NoClaimableRewards();

  mapping(address account => mapping(address token => uint256 amount)) private _rewards;
  mapping(address account => mapping(address token => uint256 amount)) private _claimableRewards;

  function _getStakedRecords()
  internal view virtual
  returns (StakedRecord[] memory);

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
    StakedRecord[] memory stakedRecords = _getStakedRecords();
    uint256 total = stakedRecords.sumWeight();
    uint256 length = stakedRecords.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      StakedRecord memory record = stakedRecords[i];
      uint256 value = amount.mulDiv(record.getWeight(), total);
      _rewards[record.account][token] = _rewards[record.account][token].unsafeAdd(value);
      _claimableRewards[record.account][token] = _claimableRewards[record.account][token].unsafeAdd(value);
    }
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
