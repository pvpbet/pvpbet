// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBetFactory} from "./interface/IBetFactory.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {Bet} from "./Bet.sol";
import {BetOption} from "./BetOption.sol";

contract BetFactory is IBetFactory, IMetadata {
  function name()
  public pure virtual
  returns (string memory) {
    return "PVPBetFactory";
  }

  function version()
  public pure virtual
  returns (string memory) {
    return "1.0.0";
  }

  function createBet(
    address betOptionFactory,
    address betManager,
    address chip,
    address vote,
    address creator,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration,
    Bet.BetDetails calldata details
  ) external returns (address) {
    return address(
      new Bet(
        betOptionFactory,
        betManager,
        chip,
        vote,
        creator,
        wageringPeriodDuration,
        decidingPeriodDuration,
        details,
        version()
      )
    );
  }
}
