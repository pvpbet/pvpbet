// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "../interface/IBet.sol";
import {IBetChip} from "../interface/IBetChip.sol";
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

  function isBetChip(address target)
  internal view
  returns (bool) {
    if (target.code.length > 0) {
      try IBetChip(target).isBetChip() returns (bool yes) {
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
}
