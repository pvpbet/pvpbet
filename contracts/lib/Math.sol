// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MathLib {
  function unsafeInc(uint256 a) internal pure returns (uint256) {
    unchecked {
      return a + 1;
    }
  }

  function unsafeDec(uint256 a) internal pure returns (uint256) {
    unchecked {
      return a - 1;
    }
  }

  function unsafeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a + b;
    }
  }

  function unsafeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a - b;
    }
  }

  function unsafeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a * b;
    }
  }

  function unsafeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      return a / b;
    }
  }

  function inc(uint256 a) internal pure returns (uint256) {
    if (a < type(uint256).max) {
      unchecked {
        return a + 1;
      }
    }
    return type(uint256).max;
  }

  function dec(uint256 a) internal pure returns (uint256) {
    if (a > 0) {
      unchecked {
        return a - 1;
      }
    }
    return 0;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      uint256 c = a + b;
      if (c < a) return type(uint256).max;
      return c;
    }
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      if (a > b) return a - b;
      return 0;
    }
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      uint256 c = a * b;
      if (c < a) return type(uint256).max;
      return c;
    }
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    unchecked {
      if (b == 0) return 0;
      return a / b;
    }
  }

  function min(uint256 a, uint256 b) internal pure returns (uint256) {
    return a < b ? a : b;
  }

  function max(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? a : b;
  }

  /**
   * @notice From "@openzeppelin/contracts/utils/math/Math.sol"
   */
  error MathOverflowedMulDiv();
  function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
    unchecked {
      uint256 prod0 = x * y;
      uint256 prod1;
      assembly {
        let mm := mulmod(x, y, not(0))
        prod1 := sub(sub(mm, prod0), lt(mm, prod0))
      }

      if (prod1 == 0) {
        return prod0 / denominator;
      }

      if (denominator <= prod1) {
        revert MathOverflowedMulDiv();
      }

      uint256 remainder;
      assembly {
        remainder := mulmod(x, y, denominator)
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
      }

      uint256 twos = denominator & (0 - denominator);
      assembly {
        denominator := div(denominator, twos)
        prod0 := div(prod0, twos)
        twos := add(div(sub(0, twos), twos), 1)
      }

      prod0 |= prod1 * twos;

      uint256 inverse = (3 * denominator) ^ 2;

      inverse *= 2 - denominator * inverse; // inverse mod 2^8
      inverse *= 2 - denominator * inverse; // inverse mod 2^16
      inverse *= 2 - denominator * inverse; // inverse mod 2^32
      inverse *= 2 - denominator * inverse; // inverse mod 2^64
      inverse *= 2 - denominator * inverse; // inverse mod 2^128
      inverse *= 2 - denominator * inverse; // inverse mod 2^256

      result = prod0 * inverse;
      return result;
    }
  }
}
