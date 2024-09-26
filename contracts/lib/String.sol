// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./Math.sol";

library StringLib {
  using MathLib for uint256;

  function isEmpty(string memory target)
  internal pure
  returns (bool) {
    return bytes(target).length == 0;
  }

  function startsWith(string memory target, string memory str)
  internal pure
  returns (bool) {
    bytes memory aBytes = bytes(target);
    bytes memory bBytes = bytes(str);

    if (bBytes.length > aBytes.length) return false;

    uint256 length = bBytes.length;
    for (uint i = 0; i < length; i = i.unsafeInc()) {
      if (aBytes[i] != bBytes[i]) return false;
    }

    return true;
  }
}
