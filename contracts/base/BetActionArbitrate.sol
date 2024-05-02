// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetActionArbitrate} from "../interface/IBetActionArbitrate.sol";
import {IErrors} from "../interface/IErrors.sol";
import {Record, RecordArrayLib} from "../lib/Record.sol";

abstract contract BetActionArbitrate is IBetActionArbitrate, IErrors {
  using RecordArrayLib for Record[];

  Record[] private _arbitratedRecords;

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
    IBet.Status status = IBet(bet()).status();
    if (status < IBet.Status.ARBITRATING) revert CurrentStatusIsNotArbitrable();
    if (status > IBet.Status.ARBITRATING) revert CurrentStatusIsNotArbitrable();

    _arbitratedRecords.remove(arbitrator).amount;

    if (amount > 0) {
      if (amount < voteMinValue()) revert InvalidAmount();
      _arbitratedRecords.add(
        Record(arbitrator, amount)
      );
    }

    emit Arbitrated(arbitrator, amount);
  }

  function arbitratedAmount()
  public view
  returns (uint256) {
    return _arbitratedRecords.sumAmount();
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
