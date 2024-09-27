// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionArbitrate} from "../interface/IBetActionArbitrate.sol";
import {IErrors} from "../interface/IErrors.sol";
import {MathLib} from "../lib/Math.sol";
import {Record, RecordArrayLib} from "../lib/Record.sol";

abstract contract BetActionArbitrate is IBetActionArbitrate, IErrors {
  using MathLib for uint256;
  using RecordArrayLib for Record[];

  Record[] private _arbitratedRecords;
  uint256 private _arbitratedTotalAmount;

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
    IBet bet_ = IBet(bet());
    IBet.Status status = bet_.status();
    if (status < IBet.Status.ARBITRATING) revert CurrentStatusIsNotArbitrable();
    if (status > IBet.Status.ARBITRATING) revert CurrentStatusIsNotArbitrable();

    uint256 arbitratedAmount_ = _arbitratedRecords.remove(arbitrator).amount;
    if (arbitratedAmount_ > 0) {
      _arbitratedTotalAmount = _arbitratedTotalAmount.sub(arbitratedAmount_);
    }

    if (amount > 0) {
      if (amount < voteMinValue()) revert InvalidAmount();
      _arbitratedRecords.add(
        Record(arbitrator, amount)
      );
      _arbitratedTotalAmount = _arbitratedTotalAmount.add(amount);
    }

    bet_.statusUpdate();
    emit Arbitrated(arbitrator, amount);
  }

  function arbitratedAmount()
  public view
  returns (uint256) {
    return _arbitratedTotalAmount;
  }

  function arbitratedAmount(address arbitrator)
  public view
  returns (uint256) {
    return _arbitratedRecords.find(arbitrator).amount;
  }

  function arbitratedRecords()
  public view
  returns (Record[] memory) {
    return _arbitratedRecords;
  }
}
