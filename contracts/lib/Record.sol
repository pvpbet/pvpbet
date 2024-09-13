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

  function remove(Record[] storage records, address account)
  internal
  returns (Record memory) {
    Record memory record = Record(address(0), 0);
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (records[i].account == account) {
        record = records[i];
        uint256 max = length.unsafeDec();
        for (uint256 j = i; j < max; j = j.unsafeInc()) {
          records[j] = records[j.unsafeInc()];
        }
        records.pop();
        break;
      }
    }
    return record;
  }

  function add(Record[] storage records, Record memory record)
  internal {
    records.push(record);
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

  function distribute(Record[] memory records, address token, uint256 amount)
  internal {
    uint256 total = sumAmount(records);
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      Record memory record = records[i];
      record.account.transferFromContract(token, record.amount.mulDiv(amount, total), true);
    }
  }
}
