// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Receivable} from "./base/Receivable.sol";
import {Upgradeable} from "./base/Upgradeable.sol";
import {UseChipToken} from "./base/UseChipToken.sol";
import {UseGovToken} from "./base/UseGovToken.sol";
import {UseVoteToken} from "./base/UseVoteToken.sol";
import {Withdrawable} from "./base/Withdrawable.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetConfigurator} from "./interface/IBetConfigurator.sol";
import {IBetFactory} from "./interface/IBetFactory.sol";
import {IBetManager} from "./interface/IBetManager.sol";
import {StringLib} from "./lib/String.sol";
import {TransferLib} from "./lib/Transfer.sol";

contract BetManager is IBetManager, Upgradeable, Receivable, Withdrawable, UseChipToken, UseVoteToken, UseGovToken {
  function name()
  public pure override
  returns (string memory) {
    return "PVPBetManager";
  }

  function version()
  public pure override
  returns (string memory) {
    return "1.0.0";
  }

  using StringLib for string;
  using TransferLib for address;

  error ServiceHasNotStartedYet();

  address private _betConfigurator;
  address private _betFactory;
  address private _betOptionFactory;
  uint256 private _creationFee;

  mapping(address bet => bool) private _betMap;

  function initialize(
    address initialBetConfigurator,
    address initialBetFactory,
    address initialBetOptionFactory,
    address initialGovToken,
    address initialChipToken,
    address initialVoteToken
  )
  public
  initializer {
    initialize();
    _setBetConfigurator(initialBetConfigurator);
    _setBetFactory(initialBetFactory);
    _setBetOptionFactory(initialBetOptionFactory);
    _setGovToken(initialGovToken);
    _setChipToken(initialChipToken);
    _setVoteToken(initialVoteToken);
  }

  function _authorizeWithdraw(address sender)
  internal view override(Withdrawable) onlyOwner {}

  function _authorizeUpdateChipToken(address sender)
  internal view override(UseChipToken) onlyOwner {}

  function _authorizeUpdateVoteToken(address sender)
  internal view override(UseVoteToken) onlyOwner {}

  function _authorizeUpdateGovToken(address sender)
  internal view override(UseGovToken) onlyOwner {}

  function betConfigurator()
  external view
  returns (address) {
    return _betConfigurator;
  }

  function setBetConfigurator(address newBetConfigurator)
  external
  onlyOwner {
    _setBetConfigurator(newBetConfigurator);
  }

  function _setBetConfigurator(address newBetConfigurator)
  private {
    _betConfigurator = newBetConfigurator;
    emit BetConfiguratorSet(newBetConfigurator);
  }

  function betFactory()
  external view
  returns (address) {
    return _betFactory;
  }

  function setBetFactory(address newBetFactory)
  external
  onlyOwner {
    _setBetFactory(newBetFactory);
  }

  function _setBetFactory(address newBetFactory)
  private {
    _betFactory = newBetFactory;
    emit BetFactorySet(newBetFactory);
  }

  function betOptionFactory()
  external view
  returns (address) {
    return _betOptionFactory;
  }

  function setBetOptionFactory(address newBetOptionFactory)
  external
  onlyOwner {
    _setBetOptionFactory(newBetOptionFactory);
  }

  function _setBetOptionFactory(address newBetOptionFactory)
  private {
    _betOptionFactory = newBetOptionFactory;
    emit BetOptionFactorySet(newBetOptionFactory);
  }

  function creationFee()
  public view
  returns (uint256) {
    return _creationFee;
  }

  function setCreationFee(uint256 fee)
  external
  onlyOwner {
    _setCreationFee(fee);
  }

  function _setCreationFee(uint256 fee)
  internal {
    _creationFee = fee;
    emit CreationFeeSet(fee);
  }

  function createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration
  ) external
  returns (address) {
    return _createBet(details, wageringPeriodDuration, decidingPeriodDuration, false);
  }

  function createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration,
    bool useChipERC20
  ) external
  returns (address) {
    return _createBet(details, wageringPeriodDuration, decidingPeriodDuration, useChipERC20);
  }

  function _createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 decidingPeriodDuration,
    bool useChipERC20
  ) private
  returns (address) {
    if (chipToken() == address(0) && useChipERC20) revert ServiceHasNotStartedYet();
    if (voteToken() == address(0)) revert ServiceHasNotStartedYet();

    IBetConfigurator configurator = IBetConfigurator(_betConfigurator);
    configurator.validateTitle(details.title);
    configurator.validateDescription(details.description);
    configurator.validateOptions(details.options);
    if (!details.forumURL.isEmpty()) {
      configurator.validateUrl(details.forumURL);
    }
    configurator.validateDuration(wageringPeriodDuration, decidingPeriodDuration);

    if (_creationFee > 0) {
      msg.sender.transferToContract(govToken(), _creationFee);
    }

    address bet = IBetFactory(_betFactory).createBet(
      configurator.betConfig(),
      details,
      wageringPeriodDuration,
      decidingPeriodDuration,
      msg.sender,
      useChipERC20 ? chipToken() : address(0),
      voteToken(),
      govToken(),
      address(this),
      _betOptionFactory
    );
    emit BetCreated(bet, msg.sender);
    _betMap[bet] = true;
    return bet;
  }

  function isBet(address bet)
  external view
  returns (bool) {
    return _betMap[bet];
  }
}
