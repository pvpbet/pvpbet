// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./Math.sol";

enum SortOrder {
  ASC,
  DESC
}

library Array2DLib {
  using MathLib for uint256;

  function sortBy(uint256[][] memory arr2d, uint256 index)
  internal pure
  returns (uint256[][] memory) {
    return sortBy(arr2d, index, SortOrder.DESC);
  }

  function sortBy(uint256[][] memory arr2d, uint256 index, SortOrder order)
  internal pure
  returns (uint256[][] memory) {
    uint256 n = arr2d.length;
    for (uint256 i = 0; i < n; i = i.unsafeInc()) {
      uint256 l = n.unsafeSub(i).unsafeDec();
      for (uint256 j = 0; j < l; j = j.unsafeInc()) {
        uint256 k = j.unsafeInc();
        if (
          (order == SortOrder.ASC && arr2d[j][index] > arr2d[k][index]) ||
          (order == SortOrder.DESC && arr2d[j][index] < arr2d[k][index])
        ) {
          uint256[] memory temp = arr2d[j];
          arr2d[j] = arr2d[k];
          arr2d[k] = temp;
        }
      }
    }
    return arr2d;
  }
}
