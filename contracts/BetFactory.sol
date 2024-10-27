// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IBetFactory} from "./interface/IBetFactory.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {Bet} from "./Bet.sol";

contract BetFactory is IBetFactory, IMetadata {
  function name()
  public pure
  returns (string memory) {
    return "PVPBetFactory";
  }

  function version()
  public pure
  returns (string memory) {
    return "1.0.1";
  }

  address private _implementation;

  function createBet(
    Bet.BetConfig calldata config,
    Bet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration,
    address creator,
    address chip,
    address vote,
    address govToken,
    address betManager,
    address betOptionFactory
  ) external returns (address) {
    Bet bet;
    if (_implementation == address(0)) {
      bet = new Bet();
      _implementation = address(bet);
    } else {
      bet = Bet(payable(Clones.clone(_implementation)));
    }
    bet.initialize(
      version(),
      config,
      details,
      wageringPeriodDuration,
      decidingPeriodDuration,
      creator,
      chip,
      vote,
      govToken,
      betManager,
      betOptionFactory
    );
    return address(bet);
  }
}
