// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IMetadata} from "../interface/IMetadata.sol";

abstract contract Upgradeable is IMetadata, Initializable, UUPSUpgradeable, OwnableUpgradeable {
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
