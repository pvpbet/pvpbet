// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract Upgradeable is Initializable, UUPSUpgradeable, OwnableUpgradeable {
  function name()
  public view virtual
  returns (string memory);

  function version()
  public pure virtual
  returns (string memory);

  function initialize()
  public virtual
  initializer {
    __Ownable_init(msg.sender);
    __UUPSUpgradeable_init();
  }

  function _authorizeUpgrade(address newImplementation)
  internal view virtual override(UUPSUpgradeable) onlyOwner {}
}
