// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetConfigurator} from "./interface/IBetConfigurator.sol";
import {IErrors} from "./interface/IErrors.sol";
import {MathLib} from "./lib/Math.sol";
import {StringLib} from "./lib/String.sol";

contract BetConfigurator is IBetConfigurator, IErrors, Ownable {
  using MathLib for uint256;
  using StringLib for string;

  error InvalidTitle(string title);
  error InvalidDescription(string description);
  error InvalidOptionCount(uint256 count);
  error InvalidVerifyingPeriodDuration(uint256 duration);
  error InvalidWageringPeriodDuration(uint256 duration);
  error InvalidUrl(string url);

  // Bet creation restrictions
  uint256 private _minOptionsCount;
  uint256 private _maxOptionsCount;
  uint256 private _minWageringPeriodDuration;
  uint256 private _maxWageringPeriodDuration;
  uint256 private _minVerifyingPeriodDuration;
  uint256 private _maxVerifyingPeriodDuration;
  string[] private _originAllowlist;
  address[] private _chipTokenAllowlist;

  // Bet configuration
  mapping(address => uint256) private _chipMinValues;
  mapping(address => uint256) private _chipMinWageredTotalAmounts;
  uint256 private _voteMinValue;
  uint256 private _minVerifiedTotalAmount;
  uint256 private _minArbitratedTotalAmount;
  uint256 private _announcementPeriodDuration;
  uint256 private _arbitratingPeriodDuration;
  uint256 private _singleOptionMaxAmountRatio;
  uint256 private _confirmDisputeAmountRatio;
  uint256 private _protocolRewardRatio;
  uint256 private _creatorRewardRatio;
  uint256 private _verifierRewardRatio;
  uint256 private _countPerRelease;
  uint256 private _countPerPenalize;

  constructor() Ownable(msg.sender) {
    _minOptionsCount = 2;
    _maxOptionsCount = 10;

    _minWageringPeriodDuration = 1 days;
    _maxWageringPeriodDuration = 90 days;
    _minVerifyingPeriodDuration = 1 days;
    _maxVerifyingPeriodDuration = 90 days;

    _chipMinValues[address(0)] = 0.001 ether;
    _chipMinWageredTotalAmounts[address(0)] = 0.2 ether;
    _voteMinValue = 1 ether;
    _minVerifiedTotalAmount = 10000 ether;
    _minArbitratedTotalAmount = 10000 ether;

    _announcementPeriodDuration = 1 days;
    _arbitratingPeriodDuration = 3 days;

    _singleOptionMaxAmountRatio = 85;
    _confirmDisputeAmountRatio = 5;
    _protocolRewardRatio = 1;
    _creatorRewardRatio = 1;
    _verifierRewardRatio = 5;

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
  public view {
    uint256 optionCount = options.length;
    if (optionCount < _minOptionsCount || optionCount > _maxOptionsCount) revert InvalidOptionCount(optionCount);
  }

  function validateDuration(uint256 wageringPeriodDuration, uint256 verifyingPeriodDuration)
  public view {
    if (
      wageringPeriodDuration < _minWageringPeriodDuration ||
      wageringPeriodDuration > _maxWageringPeriodDuration
    ) revert InvalidWageringPeriodDuration(wageringPeriodDuration);
    if (
      verifyingPeriodDuration < _minVerifyingPeriodDuration ||
      verifyingPeriodDuration > _maxVerifyingPeriodDuration
    ) revert InvalidVerifyingPeriodDuration(verifyingPeriodDuration);
  }

  function validateChipToken(address token)
  public view {
    bool isAllowedChipToken = false;
    uint256 length = _chipTokenAllowlist.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      if (token == _chipTokenAllowlist[i]) {
        isAllowedChipToken = true;
        break;
      }
    }
    if (!isAllowedChipToken) revert InvalidChip(token);
  }

  function validateUrl(string calldata url)
  public view {
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

  function betConfig(address chip)
  public view
  returns (IBet.BetConfig memory) {
    return IBet.BetConfig({
      chipMinValue: chipMinValue(chip),
      voteMinValue: _voteMinValue,
      minWageredTotalAmount: minWageredTotalAmount(chip),
      minVerifiedTotalAmount: _minVerifiedTotalAmount,
      minArbitratedTotalAmount: _minArbitratedTotalAmount,
      announcementPeriodDuration: _announcementPeriodDuration,
      arbitratingPeriodDuration: _arbitratingPeriodDuration,
      singleOptionMaxAmountRatio: _singleOptionMaxAmountRatio,
      confirmDisputeAmountRatio: _confirmDisputeAmountRatio,
      protocolRewardRatio: _protocolRewardRatio,
      creatorRewardRatio: _creatorRewardRatio,
      verifierRewardRatio: _verifierRewardRatio,
      countPerRelease: _countPerRelease,
      countPerPenalize: _countPerPenalize
    });
  }

  function minOptionsCount()
  public view
  returns (uint256) {
    return _minOptionsCount;
  }

  function setMinOptionsCount(uint256 newMinOptionsCount)
  external onlyOwner {
    _minOptionsCount = newMinOptionsCount;
  }

  function maxOptionsCount()
  public view
  returns (uint256) {
    return _maxOptionsCount;
  }

  function setMaxOptionsCount(uint256 newMaxOptionsCount)
  external onlyOwner {
    _maxOptionsCount = newMaxOptionsCount;
  }

  function minWageringPeriodDuration()
  public view
  returns (uint256) {
    return _minWageringPeriodDuration;
  }

  function setMinWageringPeriodDuration(uint256 newMinWageringPeriodDuration)
  external onlyOwner {
    _minWageringPeriodDuration = newMinWageringPeriodDuration;
  }

  function maxWageringPeriodDuration()
  public view
  returns (uint256) {
    return _maxWageringPeriodDuration;
  }

  function setMaxWageringPeriodDuration(uint256 newMaxWageringPeriodDuration)
  external onlyOwner {
    _maxWageringPeriodDuration = newMaxWageringPeriodDuration;
  }

  function minVerifyingPeriodDuration()
  public view
  returns (uint256) {
    return _minVerifyingPeriodDuration;
  }

  function setMinVerifyingPeriodDuration(uint256 newMinVerifyingPeriodDuration)
  external onlyOwner {
    _minVerifyingPeriodDuration = newMinVerifyingPeriodDuration;
  }

  function maxVerifyingPeriodDuration()
  public view
  returns (uint256) {
    return _maxVerifyingPeriodDuration;
  }

  function setMaxVerifyingPeriodDuration(uint256 newMaxVerifyingPeriodDuration)
  external onlyOwner {
    _maxVerifyingPeriodDuration = newMaxVerifyingPeriodDuration;
  }

  function originAllowlist()
  public view
  returns (string[] memory) {
    return _originAllowlist;
  }

  function setOriginAllowlist(string[] memory newOriginAllowlist)
  external onlyOwner {
    _originAllowlist = newOriginAllowlist;
  }

  function chipTokenAllowlist()
  public view
  returns (address[] memory) {
    return _chipTokenAllowlist;
  }

  function setChipTokenAllowlist(address[] memory newChipTokenAllowlist)
  external onlyOwner {
    _chipTokenAllowlist = newChipTokenAllowlist;
  }

  function chipMinValue(address chip)
  public view
  returns (uint256) {
    return _chipMinValues[chip] > 0 ? _chipMinValues[chip] : 1 ether;
  }

  function setChipMinValue(address chip, uint256 newChipMinValue)
  external onlyOwner {
    _chipMinValues[chip] = newChipMinValue;
  }

  function voteMinValue()
  public view
  returns (uint256) {
    return _voteMinValue;
  }

  function setVoteMinValue(uint256 newVoteMinValue)
  external onlyOwner {
    _voteMinValue = newVoteMinValue;
  }

  function minWageredTotalAmount(address chip)
  public view
  returns (uint256) {
    return _chipMinWageredTotalAmounts[chip] > 0 ? _chipMinWageredTotalAmounts[chip] : chipMinValue(chip) * 200;
  }

  function setMinWageredTotalAmount(address chip, uint256 newMinWageredTotalAmount)
  external onlyOwner {
    _chipMinWageredTotalAmounts[chip] = newMinWageredTotalAmount;
  }

  function minVerifiedTotalAmount()
  public view
  returns (uint256) {
    return _minVerifiedTotalAmount;
  }

  function setMinVerifiedTotalAmount(uint256 newMinVerifiedTotalAmount)
  external onlyOwner {
    _minVerifiedTotalAmount = newMinVerifiedTotalAmount;
  }

  function minArbitratedTotalAmount()
  public view
  returns (uint256) {
    return _minArbitratedTotalAmount;
  }

  function setMinArbitratedTotalAmount(uint256 newMinArbitratedTotalAmount)
  external onlyOwner {
    _minArbitratedTotalAmount = newMinArbitratedTotalAmount;
  }

  function announcementPeriodDuration()
  public view
  returns (uint256) {
    return _announcementPeriodDuration;
  }

  function setAnnouncementPeriodDuration(uint256 newAnnouncementPeriodDuration)
  external onlyOwner {
    _announcementPeriodDuration = newAnnouncementPeriodDuration;
  }

  function arbitratingPeriodDuration()
  public view
  returns (uint256) {
    return _arbitratingPeriodDuration;
  }

  function setArbitratingPeriodDuration(uint256 newArbitratingPeriodDuration)
  external onlyOwner {
    _arbitratingPeriodDuration = newArbitratingPeriodDuration;
  }

  function singleOptionMaxAmountRatio()
  public view
  returns (uint256) {
    return _singleOptionMaxAmountRatio;
  }

  function setSingleOptionMaxAmountRatio(uint256 newSingleOptionMaxAmountRatio)
  external onlyOwner {
    _singleOptionMaxAmountRatio = newSingleOptionMaxAmountRatio;
  }

  function confirmDisputeAmountRatio()
  public view
  returns (uint256) {
    return _confirmDisputeAmountRatio;
  }

  function setConfirmDisputeAmountRatio(uint256 newConfirmDisputeAmountRatio)
  external onlyOwner {
    _confirmDisputeAmountRatio = newConfirmDisputeAmountRatio;
  }

  function protocolRewardRatio()
  public view
  returns (uint256) {
    return _protocolRewardRatio;
  }

  function setProtocolRewardRatio(uint256 newProtocolRewardRatio)
  external onlyOwner {
    _protocolRewardRatio = newProtocolRewardRatio;
  }

  function creatorRewardRatio()
  public view
  returns (uint256) {
    return _creatorRewardRatio;
  }

  function setCreatorRewardRatio(uint256 newCreatorRewardRatio)
  external onlyOwner {
    _creatorRewardRatio = newCreatorRewardRatio;
  }

  function verifierRewardRatio()
  public view
  returns (uint256) {
    return _verifierRewardRatio;
  }

  function setVerifierRewardRatio(uint256 newVerifierRewardRatio)
  external onlyOwner {
    _verifierRewardRatio = newVerifierRewardRatio;
  }

  function countPerRelease()
  public view
  returns (uint256) {
    return _countPerRelease;
  }

  function setCountPerRelease(uint256 newCountPerRelease)
  external onlyOwner {
    _countPerRelease = newCountPerRelease;
  }

  function countPerPenalize()
  public view
  returns (uint256) {
    return _countPerPenalize;
  }

  function setCountPerPenalize(uint256 newCountPerPenalize)
  external onlyOwner {
    _countPerPenalize = newCountPerPenalize;
  }
}
