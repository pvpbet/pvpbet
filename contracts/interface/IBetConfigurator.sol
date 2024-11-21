// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "./IBet.sol";

interface IBetConfigurator {
  function validateTitle(string calldata title) external view;
  function validateDescription(string calldata description) external view;
  function validateOptions(string[] calldata options) external view;
  function validateDuration(uint256 wageringPeriodDuration, uint256 verifyingPeriodDuration) external view;
  function validateChipToken(address token) external view;
  function validateUrl(string calldata url) external view;

  function betConfig(address chip) external view returns (IBet.BetConfig memory);

  function minOptionsCount() external view returns (uint256);
  function setMinOptionsCount(uint256 newMinOptionsCount) external;
  function maxOptionsCount() external view returns (uint256);
  function setMaxOptionsCount(uint256 newMaxOptionsCount) external;

  function minWageringPeriodDuration() external view returns (uint256);
  function setMinWageringPeriodDuration(uint256 newMinWageringPeriodDuration) external;
  function maxWageringPeriodDuration() external view returns (uint256);
  function setMaxWageringPeriodDuration(uint256 newMaxWageringPeriodDuration) external;
  function minVerifyingPeriodDuration() external view returns (uint256);
  function setMinVerifyingPeriodDuration(uint256 newMinVerifyingPeriodDuration) external;
  function maxVerifyingPeriodDuration() external view returns (uint256);
  function setMaxVerifyingPeriodDuration(uint256 newMaxVerifyingPeriodDuration) external;

  function originAllowlist() external view returns (string[] memory);
  function setOriginAllowlist(string[] memory newOriginAllowlist) external;

  function chipTokenAllowlist() external view returns (address[] memory);
  function setChipTokenAllowlist(address[] memory newChipTokenAllowlist) external;

  function chipMinValue(address chip) external view returns (uint256);
  function setChipMinValue(address chip, uint256 newChipMinValue) external;
  function voteMinValue() external view returns (uint256);
  function setVoteMinValue(uint256 newVoteMinValue) external;

  function minWageredTotalAmount(address chip) external view returns (uint256);
  function setMinWageredTotalAmount(address chip, uint256 newMinWageredTotalAmount) external;
  function minVerifiedTotalAmount() external view returns (uint256);
  function setMinVerifiedTotalAmount(uint256 newMinVerifiedTotalAmount) external;
  function minArbitratedTotalAmount() external view returns (uint256);
  function setMinArbitratedTotalAmount(uint256 newMinArbitratedTotalAmount) external;

  function announcementPeriodDuration() external view returns (uint256);
  function setAnnouncementPeriodDuration(uint256 newAnnouncementPeriodDuration) external;
  function arbitratingPeriodDuration() external view returns (uint256);
  function setArbitratingPeriodDuration(uint256 newArbitratingPeriodDuration) external;

  function singleOptionMaxAmountRatio() external view returns (uint256);
  function setSingleOptionMaxAmountRatio(uint256 newSingleOptionMaxAmountRatio) external;
  function confirmDisputeAmountRatio() external view returns (uint256);
  function setConfirmDisputeAmountRatio(uint256 newConfirmDisputeAmountRatio) external;
  function protocolRewardRatio() external view returns (uint256);
  function setProtocolRewardRatio(uint256 newProtocolRewardRatio) external;
  function creatorRewardRatio() external view returns (uint256);
  function setCreatorRewardRatio(uint256 newCreatorRewardRatio) external;
  function verifierRewardRatio() external view returns (uint256);
  function setVerifierRewardRatio(uint256 newVerifierRewardRatio) external;

  function countPerRelease() external view returns (uint256);
  function setCountPerRelease(uint256 newCountPerRelease) external;
  function countPerPenalize() external view returns (uint256);
  function setCountPerPenalize(uint256 newCountPerPenalize) external;
}
