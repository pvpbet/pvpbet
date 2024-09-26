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
import {AddressArrayLib} from "./lib/Address.sol";
import {MathLib} from "./lib/Math.sol";
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

  using MathLib for uint256;
  using StringLib for string;
  using TransferLib for address;
  using AddressArrayLib for address[];

  error ServiceHasNotStartedYet();

  address private constant ZERO_ADDRESS = address(0);

  address private _betConfigurator;
  address private _betFactory;
  address private _betOptionFactory;
  uint256 private _creationFee;

  address[] private _activeBets;
  address[] private _bets;
  mapping(address bet => uint256 index) private _activeBetMap;
  mapping(address bet => uint256 index) private _betMap;

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
    if (chipToken() == ZERO_ADDRESS && useChipERC20) revert ServiceHasNotStartedYet();
    if (voteToken() == ZERO_ADDRESS) revert ServiceHasNotStartedYet();

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
      useChipERC20 ? chipToken() : ZERO_ADDRESS,
      voteToken(),
      address(this),
      _betOptionFactory
    );
    emit BetCreated(bet, msg.sender);
    _activeBets.push(bet);
    _activeBetMap[bet] = _activeBets.length;
    _bets.push(bet);
    _betMap[bet] = _bets.length;
    return bet;
  }

  function close()
  external {
    address sender = msg.sender;
    uint256 index = _activeBetMap[sender];
    if (index == 0) return;
    _activeBetMap[sender] = 0;
    uint256 length = _activeBets.length;
    if (index > length) return;
    uint256 max = length.unsafeDec();
    for (uint256 i = index.unsafeDec(); i < max; i = i.unsafeInc()) {
      uint256 j = i.unsafeInc();
      address bet = _activeBets[j];
      _activeBets[i] = bet;
      _activeBetMap[bet] = j;
    }
    _activeBets.pop();
  }

  function clear()
  external {
    uint256 count = 0;
    uint256 length = _activeBets.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address betAddress = _activeBets[i];
      IBet bet = IBet(betAddress);
      if (bet.status() == IBet.Status.CANCELLED) {
        bet.release();
        _activeBetMap[betAddress] = 0;
        count = count.unsafeInc();
      } else if (count > 0) {
        uint256 index = i.unsafeSub(count);
        _activeBets[index] = betAddress;
        _activeBetMap[betAddress] = index.unsafeInc();
      }
    }

    if (count > 0) {
      for (uint256 i = 0; i < count; i = i.unsafeInc()) {
        _activeBets.pop();
      }
    }
  }

  function isBet(address bet)
  external view
  returns (bool) {
    return _betMap[bet] > 0;
  }

  function betIndex(address bet)
  external view
  returns (uint256) {
    uint256 index = _betMap[bet];
    uint256 length = _bets.length;
    return index > 0 && index <= length ? length.unsafeSub(index).unsafeInc() : 0;
  }

  function betAt(uint256 index)
  external view
  returns (address) {
    uint256 length = _bets.length;
    return index > 0 && index <= length ? _bets[length.unsafeSub(index)] : ZERO_ADDRESS;
  }

  function betCount()
  external view
  returns (uint256) {
    return _bets.length;
  }

  function bets(uint256 offset, uint256 limit)
  external view
  returns (address[] memory) {
    return _bets.search(offset, limit);
  }

  function bets(uint256 offset, uint256 limit, IBet.Status[] calldata status)
  public view
  returns (address[] memory) {
    return _bets.search(offset, limit, status);
  }

  function activeBetIndex(address bet)
  external view
  returns (uint256) {
    uint256 index = _activeBetMap[bet];
    uint256 length = _activeBets.length;
    return index > 0 && index <= length ? length.unsafeSub(index).unsafeInc() : 0;
  }

  function activeBetAt(uint256 index)
  external view
  returns (address) {
    uint256 length = _activeBets.length;
    return index > 0 && index <= length ? _activeBets[length.unsafeSub(index)] : ZERO_ADDRESS;
  }

  function activeBetCount()
  external view
  returns (uint256) {
    return _activeBets.length;
  }

  function activeBets(uint256 offset, uint256 limit)
  external view
  returns (address[] memory) {
    return _activeBets.search(offset, limit);
  }

  function activeBets(uint256 offset, uint256 limit, IBet.Status[] calldata status)
  public view
  returns (address[] memory) {
    return _activeBets.search(offset, limit, status);
  }
}
