// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./Math.sol";

enum UnlockWaitingPeriod {
  NONE,
  WEEK,
  WEEK12
}

struct StakedRecord {
  address account;
  UnlockWaitingPeriod unlockWaitingPeriod;
  uint256 amount;
}

library StakedRecordLib {
  using MathLib for uint256;

  function addAmount(StakedRecord storage record, uint256 amount)
  internal {
    record.amount = record.amount.unsafeAdd(amount);
  }

  function subAmount(StakedRecord storage record, uint256 amount)
  internal {
    record.amount = record.amount > amount ? record.amount.unsafeSub(amount) : 0;
  }

  function subAmount(StakedRecord storage record, uint256 amount, uint256 minValue, StakedRecord[] storage records)
  internal
  returns (uint256) {
    subAmount(record, amount);
    minValue = minValue == 0 ? 1 : minValue;
    if (record.amount < minValue) {
      // When the reference to a record is set to storage,
      // if the current record is removed from the list,
      // the reference to the record will also be altered.
      uint256 remainingAmount = record.amount;
      StakedRecordArrayLib.remove(records, record.account, record.unlockWaitingPeriod);
      return remainingAmount;
    }
    return 0;
  }

  function getWeight(StakedRecord memory record)
  internal pure
  returns (uint256) {
    if (record.unlockWaitingPeriod == UnlockWaitingPeriod.WEEK12) {
      return record.amount.unsafeMul(2);
    } else if (record.unlockWaitingPeriod == UnlockWaitingPeriod.WEEK) {
      return record.amount;
    } else {
      return 0;
    }
  }

  function removeFrom(StakedRecord memory record, StakedRecord[] storage records)
  internal {
    StakedRecordArrayLib.remove(records, record.account, record.unlockWaitingPeriod);
  }
}

library StakedRecordArrayLib {
  using MathLib for uint256;

  function remove(StakedRecord[] storage records, address account, UnlockWaitingPeriod unlockWaitingPeriod)
  internal
  returns (StakedRecord memory) {
    StakedRecord memory removedRecord = StakedRecord(address(0), unlockWaitingPeriod, 0);
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      StakedRecord memory record = records[i];
      if (record.account == account && record.unlockWaitingPeriod == unlockWaitingPeriod) {
        removedRecord = record;
        uint256 max = length.unsafeDec();
        for (uint256 j = i; j < max; j = j.unsafeInc()) {
          records[j] = records[j.unsafeInc()];
        }
        records.pop();
        break;
      }
    }
    return removedRecord;
  }

  function add(StakedRecord[] storage records, StakedRecord memory record)
  internal {
    records.push(record);
  }

  function find(StakedRecord[] memory records, address account)
  internal pure
  returns (StakedRecord memory, uint256) {
    StakedRecord memory foundRecord = StakedRecord(address(0), UnlockWaitingPeriod.NONE, 0);
    uint256 index = 0;
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      StakedRecord memory record = records[i];
      if (record.account == account) {
        foundRecord = record;
        index = i.unsafeInc();
        break;
      }
    }
    return (foundRecord, index);
  }

  function find(StakedRecord[] memory records, address account, UnlockWaitingPeriod unlockWaitingPeriod)
  internal pure
  returns (StakedRecord memory, uint256) {
    StakedRecord memory foundRecord = StakedRecord(address(0), unlockWaitingPeriod, 0);
    uint256 index = 0;
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      StakedRecord memory record = records[i];
      if (record.account == account && record.unlockWaitingPeriod == unlockWaitingPeriod) {
        foundRecord = record;
        index = i.unsafeInc();
        break;
      }
    }
    return (foundRecord, index);
  }

  function sumAmount(StakedRecord[] memory records)
  internal pure
  returns (uint256) {
    uint256 sum = 0;
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      sum = sum.unsafeAdd(records[i].amount);
    }
    return sum;
  }

  function sumWeight(StakedRecord[] memory records)
  internal pure
  returns (uint256) {
    uint256 sum = 0;
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      sum = sum.unsafeAdd(StakedRecordLib.getWeight(records[i]));
    }
    return sum;
  }
}
