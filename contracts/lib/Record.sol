// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./Math.sol";
import {TransferLib} from "./Transfer.sol";

struct Record {
  address account;
  uint256 amount;
}

library RecordArrayLib {
  using MathLib for uint256;
  using TransferLib for address;

  function add(Record[] storage records, Record memory record)
  internal {
    records.push(record);
  }

  function remove(Record[] storage records, address account)
  internal
  returns (Record memory) {
    Record memory record = Record(address(0), 0);
    uint256 length = records.length;
    uint256 max = length.unsafeDec();
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (records[i].account == account) {
        record = records[i];
        for (uint256 j = i; j < max; j = j.unsafeInc()) {
          records[j] = records[j.unsafeInc()];
        }
        records.pop();
        break;
      }
    }
    return record;
  }

  function find(Record[] memory records, address account)
  internal pure
  returns (Record memory) {
    Record memory foundRecord = Record(address(0), 0);
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = records[i];
      if (record.account == account) {
        foundRecord = record;
        break;
      }
    }
    return foundRecord;
  }

  function sumAmount(Record[] memory records)
  internal pure
  returns (uint256) {
    uint256 sum = 0;
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      sum = sum.unsafeAdd(records[i].amount);
    }
    return sum;
  }

  function slice(Record[] memory records, uint256 offset, uint256 limit)
  internal pure
  returns (Record[] memory) {
    uint256 length = records.length;
    offset = offset.min(length);
    uint256 end = offset.add(limit).min(length);
    Record[] memory result = new Record[](end.unsafeSub(offset));
    for (uint256 i = offset; i < end; i = i.unsafeInc()) {
      result[i.unsafeSub(offset)] = records[i];
    }
    return result;
  }

  function distribute(Record[] memory records, address token, uint256 amount)
  internal {
    uint256 total = sumAmount(records);
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = records[i];
      record.account.transferFromContract(token, record.amount.mulDiv(amount, total), true);
    }
  }

  /**
   * @dev Implement distribution for a portion of the records.
   */
  function distribute(Record[] memory records, address token, uint256 amount, uint256 total)
  internal {
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = records[i];
      record.account.transferFromContract(token, record.amount.mulDiv(amount, total), true);
    }
  }
}
