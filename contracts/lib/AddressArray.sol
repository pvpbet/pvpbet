// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./Math.sol";

library AddressArrayLib {
  using MathLib for uint256;

  function includes(address[] memory arr, address addr)
  internal pure
  returns (bool) {
    uint256 length = arr.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (arr[i] == addr) return true;
    }
    return false;
  }

  function remove(address[] storage arr, address addr)
  internal {
    uint256 length = arr.length;
    uint256 max = length.unsafeDec();
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (arr[i] == addr) {
        for (uint256 j = i; j < max; j = j.unsafeInc()) {
          arr[j] = arr[j.unsafeInc()];
        }
        arr.pop();
        break;
      }
    }
  }

  function slice(address[] memory arr, uint256 offset, uint256 limit)
  internal pure
  returns (address[] memory) {
    uint256 length = arr.length;
    if (offset == 0 && limit == length) return arr;
    offset = offset.min(length);
    uint256 end = offset.add(limit).min(length);
    address[] memory newArr = new address[](end.unsafeSub(offset));
    for (uint256 i = offset; i < end; i = i.unsafeInc()) {
      newArr[i.unsafeSub(offset)] = arr[i];
    }
    return newArr;
  }
}
