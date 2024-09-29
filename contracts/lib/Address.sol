// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetOption} from "../interface/IBetOption.sol";

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
