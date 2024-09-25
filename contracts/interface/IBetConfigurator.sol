// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBet} from "./IBet.sol";

interface IBetConfigurator {
  function validateTitle(string calldata title) external view;
  function validateDescription(string calldata description) external view;
  function validateOptions(string[] calldata options) external view;
  function validateUrl(string calldata url) external view;
  function validateDuration(uint256 wageringPeriodDuration, uint256 decidingPeriodDuration) external view;

  function betConfig() external view returns (IBet.BetConfig memory);

  function minOptionsCount() external view returns (uint256);
  function setMinOptionsCount(uint256 newMinOptionsCount) external;
  function maxOptionsCount() external view returns (uint256);
  function setMaxOptionsCount(uint256 newMaxOptionsCount) external;

  function minWageringPeriodDuration() external view returns (uint256);
  function setMinWageringPeriodDuration(uint256 newMinWageringPeriodDuration) external;
  function maxWageringPeriodDuration() external view returns (uint256);
  function setMaxWageringPeriodDuration(uint256 newMaxWageringPeriodDuration) external;
  function minDecidingPeriodDuration() external view returns (uint256);
  function setMinDecidingPeriodDuration(uint256 newMinDecidingPeriodDuration) external;
  function maxDecidingPeriodDuration() external view returns (uint256);
  function setMaxDecidingPeriodDuration(uint256 newMaxDecidingPeriodDuration) external;

  function originAllowlist() external view returns (string[] memory);
  function setOriginAllowlist(string[] memory newOriginAllowlist) external;

  function minWageredTotalAmountETH() external view returns (uint256);
  function setMinWageredTotalAmountETH(uint256 newMinWageredTotalAmountETH) external;
  function minWageredTotalAmountERC20() external view returns (uint256);
  function setMinWageredTotalAmountERC20(uint256 newMinWageredTotalAmountERC20) external;

  function minDecidedTotalAmount() external view returns (uint256);
  function setMinDecidedTotalAmount(uint256 newMinDecidedTotalAmount) external;
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
  function deciderRewardRatio() external view returns (uint256);
  function setDeciderRewardRatio(uint256 newDeciderRewardRatio) external;
}
