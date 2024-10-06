// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionArbitrate} from "../interface/IBetActionArbitrate.sol";
import {IErrors} from "../interface/IErrors.sol";
import {AddressArrayLib} from "../lib/Address.sol";
import {MathLib} from "../lib/Math.sol";
import {Record} from "../lib/Record.sol";

abstract contract BetActionArbitrate is IBetActionArbitrate, IErrors {
  using MathLib for uint256;
  using AddressArrayLib for address[];

  address[] private _accounts;
  mapping(address => uint256) private _amounts;
  uint256 private _totalAmount;

  error CurrentStatusIsNotArbitrable();

  function bet()
  public view virtual
  returns (address);

  function vote()
  public view virtual
  returns (address);

  function voteMinValue()
  public view virtual
  returns (uint256) {
    return 0;
  }

  modifier onlyVote() virtual {
    if (msg.sender != vote()) {
      revert UnauthorizedAccess(msg.sender);
    }
    _;
  }

  function arbitrate(uint256 amount)
  public virtual {
    _arbitrate(msg.sender, amount);
  }

  function arbitrate(address arbitrator, uint256 amount)
  public virtual
  onlyVote {
    _arbitrate(arbitrator, amount);
  }

  function _arbitrate(address arbitrator, uint256 amount)
  internal {
    IBet.Status status = IBet(bet()).statusUpdate();
    if (status < IBet.Status.ARBITRATING) revert CurrentStatusIsNotArbitrable();
    if (status > IBet.Status.ARBITRATING) revert CurrentStatusIsNotArbitrable();

    uint256 arbitratedAmount_ = _amounts[arbitrator];
    if (arbitratedAmount_ > 0) {
      _amounts[arbitrator] = 0;
      _totalAmount = _totalAmount.unsafeSub(arbitratedAmount_);
      _accounts.remove(arbitrator);
    }

    if (amount > 0) {
      if (amount < voteMinValue()) revert InvalidAmount();
      _amounts[arbitrator] = amount;
      _totalAmount = _totalAmount.unsafeAdd(amount);
      _accounts.push(arbitrator);
    }

    emit Arbitrated(arbitrator, amount);
  }

  function arbitratedAmount()
  public view
  returns (uint256) {
    return _totalAmount;
  }

  function arbitratedAmount(address arbitrator)
  public view
  returns (uint256) {
    return _amounts[arbitrator];
  }

  function arbitratedRecords()
  public view
  returns (Record[] memory) {
    return arbitratedRecords(0, _accounts.length);
  }

  function arbitratedRecords(uint256 offset, uint256 limit)
  public view
  returns (Record[] memory) {
    address[] memory accounts = _accounts.slice(offset, limit);
    uint256 length = accounts.length;
    Record[] memory arr = new Record[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address account = accounts[i];
      arr[i] = Record(account, _amounts[account]);
    }
    return arr;
  }

  function arbitratedRecordCount()
  public view
  returns (uint256) {
    return _accounts.length;
  }
}
