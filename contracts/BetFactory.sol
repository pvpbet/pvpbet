// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBetFactory} from "./interface/IBetFactory.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {Bet} from "./Bet.sol";
import {BetOption} from "./BetOption.sol";

contract BetFactory is IBetFactory, IMetadata {
  function name()
  public pure
  returns (string memory) {
    return "PVPBetFactory";
  }

  function version()
  public pure
  returns (string memory) {
    return "1.0.0";
  }

  function createBet(
    Bet.BetConfig calldata config,
    Bet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration,
    address creator,
    address chip,
    address vote,
    address betManager,
    address betOptionFactory
  ) external returns (address) {
    return address(
      new Bet(
        version(),
        config,
        details,
        wageringPeriodDuration,
        decidingPeriodDuration,
        creator,
        chip,
        vote,
        betManager,
        betOptionFactory
      )
    );
  }
}
