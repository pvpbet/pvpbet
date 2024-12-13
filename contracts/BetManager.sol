// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Receivable} from "./base/Receivable.sol";
import {Upgradeable} from "./base/Upgradeable.sol";
import {UseGovToken} from "./base/UseGovToken.sol";
import {UseVotingEscrow} from "./base/UseVotingEscrow.sol";
import {Withdrawable} from "./base/Withdrawable.sol";
import {IBet} from "./interface/IBet.sol";
import {IBetConfigurator} from "./interface/IBetConfigurator.sol";
import {IBetChipManager} from "./interface/IBetChipManager.sol";
import {IBetFactory} from "./interface/IBetFactory.sol";
import {IBetManager} from "./interface/IBetManager.sol";
import {IMetadata} from "./interface/IMetadata.sol";
import {StringLib} from "./lib/String.sol";
import {TransferLib} from "./lib/Transfer.sol";

contract BetManager is IBetManager, Upgradeable, Receivable, Withdrawable, UseVotingEscrow, UseGovToken {
  function name()
  public pure override
  returns (string memory) {
    return "PVPBetManager";
  }

  function version()
  public pure override
  returns (string memory) {
    return "1.2.0";
  }

  using StringLib for string;
  using TransferLib for address;

  error ServiceHasNotStartedYet();

  address private _betChipManager;
  address private _betConfigurator;
  address private _betFactory;
  address private _betOptionFactory;
  uint256 private _creationFee;

  mapping(address bet => bool) private _betMap;

  function initialize(
    address initialBetChipManager,
    address initialBetConfigurator,
    address initialBetFactory,
    address initialBetOptionFactory,
    address initialVotingEscrow,
    address initialGovToken
  )
  public
  initializer {
    initialize();
    _setBetChipManager(initialBetChipManager);
    _setBetConfigurator(initialBetConfigurator);
    _setBetFactory(initialBetFactory);
    _setBetOptionFactory(initialBetOptionFactory);
    _setVotingEscrow(initialVotingEscrow);
    _setGovToken(initialGovToken);
  }

  function _authorizeWithdraw(address sender)
  internal view override(Withdrawable) onlyOwner {}

  function _authorizeUpdateVotingEscrow(address sender)
  internal view override(UseVotingEscrow) onlyOwner {}

  function _authorizeUpdateGovToken(address sender)
  internal view override(UseGovToken) onlyOwner {}

  function betChipManager()
  external view
  returns (address) {
    return _betChipManager;
  }

  function setBetChipManager(address newBetChipManager)
  external
  onlyOwner {
    _setBetChipManager(newBetChipManager);
  }

  function _setBetChipManager(address newBetChipManager)
  private {
    _betChipManager = newBetChipManager;
    emit BetChipManagerSet(newBetChipManager);
  }

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
    uint256 verifyingPeriodDuration
  ) external
  returns (address) {
    return _createBet(details, wageringPeriodDuration, verifyingPeriodDuration, address(0));
  }

  function createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 verifyingPeriodDuration,
    address chip
  ) external
  returns (address) {
    return _createBet(details, wageringPeriodDuration, verifyingPeriodDuration, chip);
  }

  function _createBet(
    IBet.BetDetails calldata details,
    uint256 wageringPeriodDuration,
    uint256 verifyingPeriodDuration,
    address chip
  ) private
  returns (address) {
    if (votingEscrow() == address(0)) revert ServiceHasNotStartedYet();

    IBetConfigurator configurator = IBetConfigurator(_betConfigurator);
    configurator.validateTitle(details.title);
    configurator.validateDescription(details.description);
    configurator.validateOptions(details.options);
    configurator.validateDuration(wageringPeriodDuration, verifyingPeriodDuration);

    if (chip != address(0) && !IBetChipManager(_betChipManager).isBetChip(chip)) {
      configurator.validateChipToken(chip);
    }

    if (!details.forumURL.isEmpty()) {
      configurator.validateUrl(details.forumURL);
    }

    uint256 creationFee_ = _creationFee;
    if (creationFee_ > 0) {
      msg.sender.transferToContract(govToken(), creationFee_);
    }

    address bet = IBetFactory(_betFactory).createBet(
      configurator.betConfig(chip),
      details,
      wageringPeriodDuration,
      verifyingPeriodDuration,
      msg.sender,
      chip,
      votingEscrow(),
      govToken(),
      address(this),
      _betOptionFactory
    );
    emit BetCreated(
      bet,
      chip,
      msg.sender,
      block.timestamp,
      betVersion()
    );
    _betMap[bet] = true;
    return bet;
  }

  function isBet(address bet)
  external view
  returns (bool) {
    return _betMap[bet];
  }

  function betVersion()
  public view
  returns (string memory) {
    return IMetadata(_betFactory).version();
  }

  function betOptionVersion()
  public view
  returns (string memory) {
    return IMetadata(_betOptionFactory).version();
  }
}
