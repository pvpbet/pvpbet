// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetOption} from "../interface/IBetOption.sol";
import {MathLib} from "./Math.sol";

library AddressLib {
  function isContractSender()
  internal view
  returns (bool) {
    return msg.sender.code.length > 0 || msg.sender != tx.origin;
  }

  function isBet(address target)
  internal view
  returns (bool) {
    if (target.code.length > 0) {
      try IBet(target).isBet() returns (bool yes) {
        return yes;
      } catch {}
    }
    return false;
  }

  function isBetOption(address target)
  internal view
  returns (bool) {
    if (target.code.length > 0) {
      try IBetOption(target).isBetOption() returns (bool yes) {
        return yes;
      } catch {}
    }
    return false;
  }

  function decimals(address target)
  internal view
  returns (uint8) {
    if (target.code.length > 0) {
      (bool success, bytes memory result) = target.staticcall(
        abi.encodeWithSignature("decimals()")
      );
      if (success) {
        return abi.decode(result, (uint8));
      }
    }
    return 18;
  }

  /**
   * @notice From "@openzeppelin/contracts/utils/Address.sol"
   */
  error AddressInsufficientBalance(address account);
  error AddressEmptyCode(address target);
  error FailedInnerCall();
  function functionCallWithValue(address target, bytes memory data, uint256 value)
  internal
  returns (bytes memory) {
    if (address(this).balance < value) {
      revert AddressInsufficientBalance(address(this));
    }
    (bool success, bytes memory result) = target.call{value: value}(data);
    if (!success) {
      if (result.length > 0) {
        assembly {
          let result_size := mload(result)
          revert(add(32, result), result_size)
        }
      } else {
        revert FailedInnerCall();
      }
    } else if (result.length == 0 && target.code.length == 0) {
      revert AddressEmptyCode(target);
    }
    return result;
  }
}

library AddressArrayLib {
  using MathLib for uint256;

  function search(address[] memory target, uint256 offset, uint256 limit)
  internal view
  returns (address[] memory) {
    return search(target, offset, limit, new IBet.Status[](0));
  }

  function search(address[] memory target, uint256 offset, uint256 limit, IBet.Status[] memory statuses)
  internal view
  returns (address[] memory) {
    uint256 statusLength = statuses.length;
    address[] memory matchedBets = new address[](limit);

    uint256 count = 0;
    for (uint256 i = target.length.sub(offset); i > 0; i = i.unsafeDec()) {
      address bet = target[i.unsafeDec()];
      if (statusLength > 0) {
        IBet.Status status = IBet(bet).status();
        for (uint256 j = 0; j < statusLength; j = j.unsafeInc()) {
          if (status == statuses[j]) {
            matchedBets[count] = bet;
            count = count.unsafeInc();
            break;
          }
        }
      } else {
        matchedBets[count] = bet;
        count = count.unsafeInc();
      }

      if (count == limit) break;
    }

    if (count < limit) {
      assembly {
        mstore(matchedBets, count)
      }
    }

    return matchedBets;
  }
}
