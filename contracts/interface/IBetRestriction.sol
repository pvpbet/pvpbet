// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBetRestriction {
  function minOptionsCount() external view returns (uint256);
  function maxOptionsCount() external view returns (uint256);
  function minWageringPeriodDuration() external view returns (uint256);
  function maxWageringPeriodDuration() external view returns (uint256);
  function minDecidingPeriodDuration() external view returns (uint256);
  function maxDecidingPeriodDuration() external view returns (uint256);
  function originWhitelist() external view returns (string[] memory);

  function setMinOptionsCount(uint256 newMinOptionsCount) external;
  function setMaxOptionsCount(uint256 newMaxOptionsCount) external;
  function setMinWageringPeriodDuration(uint256 newMinWageringPeriodDuration) external;
  function setMaxWageringPeriodDuration(uint256 newMaxWageringPeriodDuration) external;
  function setMinDecidingPeriodDuration(uint256 newMinDecidingPeriodDuration) external;
  function setMaxDecidingPeriodDuration(uint256 newMaxDecidingPeriodDuration) external;
  function setOriginWhitelist(string[] memory newOriginWhitelist) external;
}
