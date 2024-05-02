// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBetRestriction} from "../interface/IBetRestriction.sol";
import {MathLib} from "../lib/Math.sol";
import {StringLib} from "../lib/String.sol";

abstract contract BetRestriction is IBetRestriction {
  using MathLib for uint256;
  using StringLib for string;

  error InvalidTitle(string title);
  error InvalidDescription(string description);
  error InvalidUrl(string url);
  error InvalidOptionCount(uint256 count);
  error InvalidWageringPeriodDuration(uint256 duration);
  error InvalidDecidingPeriodDuration(uint256 duration);

  uint256 private _minOptionsCount;
  uint256 private _maxOptionsCount;
  uint256 private _minWageringPeriodDuration;
  uint256 private _maxWageringPeriodDuration;
  uint256 private _minDecidingPeriodDuration;
  uint256 private _maxDecidingPeriodDuration;
  string[] private _originWhitelist;

  function _authorizeBetRestrictionUpdate(address sender)
  internal virtual;

  function initialize()
  public virtual {
    _minOptionsCount = 2;
    _maxOptionsCount = 10;
    _minWageringPeriodDuration = 2 days;
    _maxWageringPeriodDuration = 60 days;
    _minDecidingPeriodDuration = 2 days;
    _maxDecidingPeriodDuration = 60 days;
  }

  function validateTitle(string calldata title)
  internal view virtual {
    if (title.isEmpty()) revert InvalidTitle(title);
  }

  function validateDescription(string calldata description)
  internal view virtual {
    if (description.isEmpty()) revert InvalidDescription(description);
  }

  function validateOptions(string[] calldata options)
  internal view virtual {
    uint256 optionCount = options.length;
    if (optionCount < _minOptionsCount || optionCount > _maxOptionsCount) revert InvalidOptionCount(optionCount);
  }

  function validateUrl(string calldata url)
  internal view virtual {
    bool isAllowedOrigin = false;
    uint256 length = _originWhitelist.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (url.startsWith(_originWhitelist[i])) {
        isAllowedOrigin = true;
        break;
      }
    }
    if (!isAllowedOrigin) revert InvalidUrl(url);
  }

  function validateDuration(uint256 wageringPeriodDuration, uint256 decidingPeriodDuration)
  internal view virtual {
    if (
      wageringPeriodDuration < _minWageringPeriodDuration ||
      wageringPeriodDuration > _maxWageringPeriodDuration
    ) revert InvalidWageringPeriodDuration(wageringPeriodDuration);
    if (
      decidingPeriodDuration < _minDecidingPeriodDuration ||
      decidingPeriodDuration > _maxDecidingPeriodDuration
    ) revert InvalidDecidingPeriodDuration(decidingPeriodDuration);
  }

  function minOptionsCount()
  external view
  returns (uint256) {
    return _minOptionsCount;
  }

  function maxOptionsCount()
  external view
  returns (uint256) {
    return _maxOptionsCount;
  }

  function minWageringPeriodDuration()
  external view
  returns (uint256) {
    return _minWageringPeriodDuration;
  }

  function maxWageringPeriodDuration()
  external view
  returns (uint256) {
    return _maxWageringPeriodDuration;
  }

  function minDecidingPeriodDuration()
  external view
  returns (uint256) {
    return _minDecidingPeriodDuration;
  }

  function maxDecidingPeriodDuration()
  external view
  returns (uint256) {
    return _maxDecidingPeriodDuration;
  }

  function originWhitelist()
  external view
  returns (string[] memory) {
    return _originWhitelist;
  }

  function setMinOptionsCount(uint256 newMinOptionsCount)
  public {
    _authorizeBetRestrictionUpdate(msg.sender);
    _minOptionsCount = newMinOptionsCount;
  }

  function setMaxOptionsCount(uint256 newMaxOptionsCount)
  public {
    _authorizeBetRestrictionUpdate(msg.sender);
    _maxOptionsCount = newMaxOptionsCount;
  }

  function setMinWageringPeriodDuration(uint256 newMinWageringPeriodDuration)
  public {
    _authorizeBetRestrictionUpdate(msg.sender);
    _minWageringPeriodDuration = newMinWageringPeriodDuration;
  }

  function setMaxWageringPeriodDuration(uint256 newMaxWageringPeriodDuration)
  public {
    _authorizeBetRestrictionUpdate(msg.sender);
    _maxWageringPeriodDuration = newMaxWageringPeriodDuration;
  }

  function setMinDecidingPeriodDuration(uint256 newMinDecidingPeriodDuration)
  public {
    _authorizeBetRestrictionUpdate(msg.sender);
    _minDecidingPeriodDuration = newMinDecidingPeriodDuration;
  }

  function setMaxDecidingPeriodDuration(uint256 newMaxDecidingPeriodDuration)
  public {
    _authorizeBetRestrictionUpdate(msg.sender);
    _maxDecidingPeriodDuration = newMaxDecidingPeriodDuration;
  }

  function setOriginWhitelist(string[] memory newOriginWhitelist)
  public {
    _authorizeBetRestrictionUpdate(msg.sender);
    _originWhitelist = newOriginWhitelist;
  }
}
