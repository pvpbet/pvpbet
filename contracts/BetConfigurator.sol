// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetConfigurator} from "./interface/IBetConfigurator.sol";
import {MathLib} from "./lib/Math.sol";
import {StringLib} from "./lib/String.sol";

contract BetConfigurator is IBetConfigurator, Ownable {
  using MathLib for uint256;
  using StringLib for string;

  error InvalidTitle(string title);
  error InvalidDescription(string description);
  error InvalidUrl(string url);
  error InvalidOptionCount(uint256 count);
  error InvalidWageringPeriodDuration(uint256 duration);
  error InvalidDecidingPeriodDuration(uint256 duration);

  // Bet creation restrictions
  uint256 private _minOptionsCount;
  uint256 private _maxOptionsCount;
  uint256 private _minWageringPeriodDuration;
  uint256 private _maxWageringPeriodDuration;
  uint256 private _minDecidingPeriodDuration;
  uint256 private _maxDecidingPeriodDuration;
  string[] private _originAllowlist;

  // Bet configuration
  uint256 private _minWageredTotalAmountETH;
  uint256 private _minWageredTotalQuantityERC20;
  uint256 private _minDecidedTotalQuantity;
  uint256 private _minArbitratedTotalQuantity;
  uint256 private _announcementPeriodDuration;
  uint256 private _arbitratingPeriodDuration;
  uint256 private _singleOptionMaxAmountRatio;
  uint256 private _confirmDisputeAmountRatio;
  uint256 private _protocolRewardRatio;
  uint256 private _creatorRewardRatio;
  uint256 private _deciderRewardRatio;
  uint256 private _countPerRelease;
  uint256 private _countPerPenalize;

  constructor() Ownable(msg.sender) {
    _minOptionsCount = 2;
    _maxOptionsCount = 10;

    _minWageringPeriodDuration = 2 days;
    _maxWageringPeriodDuration = 90 days;
    _minDecidingPeriodDuration = 2 days;
    _maxDecidingPeriodDuration = 90 days;

    _minWageredTotalAmountETH = 5 ether;
    _minWageredTotalQuantityERC20 = 10000;
    _minDecidedTotalQuantity = 10000;
    _minArbitratedTotalQuantity = 10000;

    _announcementPeriodDuration = 2 days;
    _arbitratingPeriodDuration = 3 days;

    _singleOptionMaxAmountRatio = 85;
    _confirmDisputeAmountRatio = 5;
    _protocolRewardRatio = 1;
    _creatorRewardRatio = 1;
    _deciderRewardRatio = 5;

    _countPerRelease = 1600;
    _countPerPenalize = 200;
  }

  function validateTitle(string calldata title)
  external pure {
    if (title.isEmpty()) revert InvalidTitle(title);
  }

  function validateDescription(string calldata description)
  external pure {
    if (description.isEmpty()) revert InvalidDescription(description);
  }

  function validateOptions(string[] calldata options)
  external view {
    uint256 optionCount = options.length;
    if (optionCount < _minOptionsCount || optionCount > _maxOptionsCount) revert InvalidOptionCount(optionCount);
  }

  function validateUrl(string calldata url)
  external view {
    bool isAllowedOrigin = false;
    uint256 length = _originAllowlist.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (url.startsWith(_originAllowlist[i])) {
        isAllowedOrigin = true;
        break;
      }
    }
    if (!isAllowedOrigin) revert InvalidUrl(url);
  }

  function validateDuration(uint256 wageringPeriodDuration, uint256 decidingPeriodDuration)
  external view {
    if (
      wageringPeriodDuration < _minWageringPeriodDuration ||
      wageringPeriodDuration > _maxWageringPeriodDuration
    ) revert InvalidWageringPeriodDuration(wageringPeriodDuration);
    if (
      decidingPeriodDuration < _minDecidingPeriodDuration ||
      decidingPeriodDuration > _maxDecidingPeriodDuration
    ) revert InvalidDecidingPeriodDuration(decidingPeriodDuration);
  }

  function betConfig()
  external view
  returns (IBet.BetConfig memory) {
    return IBet.BetConfig({
      minWageredTotalAmountETH: _minWageredTotalAmountETH,
      minWageredTotalQuantityERC20: _minWageredTotalQuantityERC20,
      minDecidedTotalQuantity: _minDecidedTotalQuantity,
      minArbitratedTotalQuantity: _minArbitratedTotalQuantity,
      announcementPeriodDuration: _announcementPeriodDuration,
      arbitratingPeriodDuration: _arbitratingPeriodDuration,
      singleOptionMaxAmountRatio: _singleOptionMaxAmountRatio,
      confirmDisputeAmountRatio: _confirmDisputeAmountRatio,
      protocolRewardRatio: _protocolRewardRatio,
      creatorRewardRatio: _creatorRewardRatio,
      deciderRewardRatio: _deciderRewardRatio,
      countPerRelease: _countPerRelease,
      countPerPenalize: _countPerPenalize
    });
  }

  function minOptionsCount()
  external view
  returns (uint256) {
    return _minOptionsCount;
  }

  function setMinOptionsCount(uint256 newMinOptionsCount)
  external onlyOwner {
    _minOptionsCount = newMinOptionsCount;
  }

  function maxOptionsCount()
  external view
  returns (uint256) {
    return _maxOptionsCount;
  }

  function setMaxOptionsCount(uint256 newMaxOptionsCount)
  external onlyOwner {
    _maxOptionsCount = newMaxOptionsCount;
  }

  function minWageringPeriodDuration()
  external view
  returns (uint256) {
    return _minWageringPeriodDuration;
  }

  function setMinWageringPeriodDuration(uint256 newMinWageringPeriodDuration)
  external onlyOwner {
    _minWageringPeriodDuration = newMinWageringPeriodDuration;
  }

  function maxWageringPeriodDuration()
  external view
  returns (uint256) {
    return _maxWageringPeriodDuration;
  }

  function setMaxWageringPeriodDuration(uint256 newMaxWageringPeriodDuration)
  external onlyOwner {
    _maxWageringPeriodDuration = newMaxWageringPeriodDuration;
  }

  function minDecidingPeriodDuration()
  external view
  returns (uint256) {
    return _minDecidingPeriodDuration;
  }

  function setMinDecidingPeriodDuration(uint256 newMinDecidingPeriodDuration)
  external onlyOwner {
    _minDecidingPeriodDuration = newMinDecidingPeriodDuration;
  }

  function maxDecidingPeriodDuration()
  external view
  returns (uint256) {
    return _maxDecidingPeriodDuration;
  }

  function setMaxDecidingPeriodDuration(uint256 newMaxDecidingPeriodDuration)
  external onlyOwner {
    _maxDecidingPeriodDuration = newMaxDecidingPeriodDuration;
  }

  function originAllowlist()
  external view
  returns (string[] memory) {
    return _originAllowlist;
  }

  function setOriginAllowlist(string[] memory newOriginAllowlist)
  external onlyOwner {
    _originAllowlist = newOriginAllowlist;
  }

  function minWageredTotalAmountETH()
  external view
  returns (uint256) {
    return _minWageredTotalAmountETH;
  }

  function setMinWageredTotalAmountETH(uint256 newMinWageredTotalAmountETH)
  external onlyOwner {
    _minWageredTotalAmountETH = newMinWageredTotalAmountETH;
  }

  function minWageredTotalQuantityERC20()
  external view
  returns (uint256) {
    return _minWageredTotalQuantityERC20;
  }

  function setMinWageredTotalQuantityERC20(uint256 newMinWageredTotalQuantityERC20)
  external onlyOwner {
    _minWageredTotalQuantityERC20 = newMinWageredTotalQuantityERC20;
  }

  function minDecidedTotalQuantity()
  external view
  returns (uint256) {
    return _minDecidedTotalQuantity;
  }

  function setMinDecidedTotalQuantity(uint256 newMinDecidedTotalQuantity)
  external onlyOwner {
    _minDecidedTotalQuantity = newMinDecidedTotalQuantity;
  }

  function minArbitratedTotalQuantity()
  external view
  returns (uint256) {
    return _minArbitratedTotalQuantity;
  }

  function setMinArbitratedTotalQuantity(uint256 newMinArbitratedTotalQuantity)
  external onlyOwner {
    _minArbitratedTotalQuantity = newMinArbitratedTotalQuantity;
  }

  function announcementPeriodDuration()
  external view
  returns (uint256) {
    return _announcementPeriodDuration;
  }

  function setAnnouncementPeriodDuration(uint256 newAnnouncementPeriodDuration)
  external onlyOwner {
    _announcementPeriodDuration = newAnnouncementPeriodDuration;
  }

  function arbitratingPeriodDuration()
  external view
  returns (uint256) {
    return _arbitratingPeriodDuration;
  }

  function setArbitratingPeriodDuration(uint256 newArbitratingPeriodDuration)
  external onlyOwner {
    _arbitratingPeriodDuration = newArbitratingPeriodDuration;
  }

  function singleOptionMaxAmountRatio()
  external view
  returns (uint256) {
    return _singleOptionMaxAmountRatio;
  }

  function setSingleOptionMaxAmountRatio(uint256 newSingleOptionMaxAmountRatio)
  external onlyOwner {
    _singleOptionMaxAmountRatio = newSingleOptionMaxAmountRatio;
  }

  function confirmDisputeAmountRatio()
  external view
  returns (uint256) {
    return _confirmDisputeAmountRatio;
  }

  function setConfirmDisputeAmountRatio(uint256 newConfirmDisputeAmountRatio)
  external onlyOwner {
    _confirmDisputeAmountRatio = newConfirmDisputeAmountRatio;
  }

  function protocolRewardRatio()
  external view
  returns (uint256) {
    return _protocolRewardRatio;
  }

  function setProtocolRewardRatio(uint256 newProtocolRewardRatio)
  external onlyOwner {
    _protocolRewardRatio = newProtocolRewardRatio;
  }

  function creatorRewardRatio()
  external view
  returns (uint256) {
    return _creatorRewardRatio;
  }

  function setCreatorRewardRatio(uint256 newCreatorRewardRatio)
  external onlyOwner {
    _creatorRewardRatio = newCreatorRewardRatio;
  }

  function deciderRewardRatio()
  external view
  returns (uint256) {
    return _deciderRewardRatio;
  }

  function setDeciderRewardRatio(uint256 newDeciderRewardRatio)
  external onlyOwner {
    _deciderRewardRatio = newDeciderRewardRatio;
  }

  function countPerRelease()
  external view
  returns (uint256) {
    return _countPerRelease;
  }

  function setCountPerRelease(uint256 newCountPerRelease)
  external onlyOwner {
    _countPerRelease = newCountPerRelease;
  }

  function countPerPenalize()
  external view
  returns (uint256) {
    return _countPerPenalize;
  }

  function setCountPerPenalize(uint256 newCountPerPenalize)
  external onlyOwner {
    _countPerPenalize = newCountPerPenalize;
  }
}
