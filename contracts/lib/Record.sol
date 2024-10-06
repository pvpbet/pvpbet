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
