// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IGovTokenStaking} from "../interface/IGovTokenStaking.sol";
import {MathLib} from "./Math.sol";

struct UnstakedRecord {
  IGovTokenStaking.UnlockWaitingPeriod unlockWaitingPeriod;
  uint256 amount;
  uint256 unlockTime;
}

library UnstakedRecordArrayLib {
  using MathLib for uint256;

  function add(UnstakedRecord[] storage records, UnstakedRecord memory record)
  internal {
    if (record.unlockWaitingPeriod == IGovTokenStaking.UnlockWaitingPeriod.WEEK12) {
      record.unlockTime = block.timestamp.unsafeAdd(12 weeks);
    } else if (record.unlockWaitingPeriod == IGovTokenStaking.UnlockWaitingPeriod.WEEK) {
      record.unlockTime = block.timestamp.unsafeAdd(1 weeks);
    } else {
      record.unlockTime = block.timestamp;
    }
    records.push(record);
  }

  function remove(UnstakedRecord[] storage records, uint256 index)
  internal {
    uint256 length = records.length;
    if (index >= length) return;
    uint256 max = length.unsafeDec();
    for (uint256 i = index; i < max; i = i.unsafeInc()) {
      records[i] = records[i.unsafeInc()];
    }
    records.pop();
  }

  function removeByUnlocked(UnstakedRecord[] storage records)
  internal
  returns (UnstakedRecord[] memory) {
    uint256 blockTimestamp = block.timestamp;
    uint256 count = 0;
    uint256 length = records.length;
    UnstakedRecord[] memory matchedRecords = new UnstakedRecord[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      UnstakedRecord memory record = records[i];
      if (blockTimestamp > record.unlockTime) {
        matchedRecords[count] = record;
        count = count.unsafeInc();
      } else if (count > 0) {
        records[i.unsafeSub(count)] = record;
      }
    }

    if (count > 0) {
      for (uint256 i = 0; i < count; i = i.unsafeInc()) {
        records.pop();
      }
    }

    if (count < length) {
      assembly {
        mstore(matchedRecords, count)
      }
    }

    return matchedRecords;
  }

  function findByUnlockWaitingPeriod(UnstakedRecord[] memory records, IGovTokenStaking.UnlockWaitingPeriod unlockWaitingPeriod)
  internal pure
  returns (UnstakedRecord[] memory) {
    uint256 count = 0;
    uint256 length = records.length;
    UnstakedRecord[] memory matchedRecords = new UnstakedRecord[](length);
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      UnstakedRecord memory record = records[i];
      if (record.unlockWaitingPeriod == unlockWaitingPeriod) {
        matchedRecords[count] = record;
        count = count.unsafeInc();
      }
    }
    if (count < length) {
      assembly {
        mstore(matchedRecords, count)
      }
    }
    return matchedRecords;
  }
}
