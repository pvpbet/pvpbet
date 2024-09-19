// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UnlockWaitingPeriod} from "./StakedRecord.sol";
import {MathLib} from "./Math.sol";

struct UnstakedRecord {
  address account;
  UnlockWaitingPeriod unlockWaitingPeriod;
  uint256 amount;
  uint256 unlockTime;
  uint256 index;
}

library UnstakedRecordLib {
  function removeFrom(UnstakedRecord memory record, UnstakedRecord[] storage records)
  internal {
    UnstakedRecordArrayLib.remove(records, record.index);
  }
}

library UnstakedRecordArrayLib {
  using MathLib for uint256;

  function remove(UnstakedRecord[] storage records, uint256 index)
  internal {
    uint256 length = records.length;
    if (index >= length) return;
    uint256 max = length.unsafeDec();
    for (uint256 i = index; i < max; i = i.unsafeInc()) {
      UnstakedRecord memory record = records[i.unsafeInc()];
      record.index = i;
      records[i] = record;
    }
    records.pop();
  }

  function add(UnstakedRecord[] storage records, UnstakedRecord memory record)
  internal {
    if (record.unlockWaitingPeriod == UnlockWaitingPeriod.WEEK12) {
      record.unlockTime = block.timestamp.unsafeAdd(12 weeks);
    } else if (record.unlockWaitingPeriod == UnlockWaitingPeriod.WEEK) {
      record.unlockTime = block.timestamp.unsafeAdd(1 weeks);
    } else {
      record.unlockTime = block.timestamp;
    }
    record.index = records.length;
    records.push(record);
  }

  function find(UnstakedRecord[] memory records, address account)
  internal pure
  returns (UnstakedRecord[] memory) {
    uint256 length = records.length;

    uint256 count = 0;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (records[i].account == account) {
        count = count.unsafeInc();
      }
    }

    UnstakedRecord[] memory accountRecords = new UnstakedRecord[](count);
    uint256 j = 0;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      UnstakedRecord memory record = records[i];
      if (record.account == account) {
        accountRecords[j] = record;
        j = j.unsafeInc();
      }
    }

    return accountRecords;
  }

  function find(UnstakedRecord[] memory records, address account, UnlockWaitingPeriod unlockWaitingPeriod)
  internal pure
  returns (UnstakedRecord[] memory) {
    uint256 length = records.length;

    uint256 count = 0;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (records[i].account == account) {
        count = count.unsafeInc();
      }
    }

    UnstakedRecord[] memory accountRecords = new UnstakedRecord[](count);
    uint256 j = 0;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      UnstakedRecord memory record = records[i];
      if (record.account == account && record.unlockWaitingPeriod == unlockWaitingPeriod) {
        accountRecords[j] = record;
        j = j.unsafeInc();
      }
    }

    return accountRecords;
  }
}
