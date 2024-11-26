// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Upgradeable} from "./base/Upgradeable.sol";
import {UseGovToken} from "./base/UseGovToken.sol";
import {UseVotingEscrow} from "./base/UseVotingEscrow.sol";
import {IErrors} from "./interface/IErrors.sol";
import {IGovTokenStaking} from "./interface/IGovTokenStaking.sol";
import {IVotingEscrow} from "./interface/IVotingEscrow.sol";
import {AddressArrayLib} from "./lib/AddressArray.sol";
import {MathLib} from "./lib/Math.sol";
import {TransferLib} from "./lib/Transfer.sol";
import {UnstakedRecord, UnstakedRecordArrayLib} from "./lib/UnstakedRecord.sol";

contract GovTokenStaking is IGovTokenStaking, IErrors, Upgradeable, UseVotingEscrow, UseGovToken {
  function name()
  public pure override
  returns (string memory) {
    return "PVPBetGovTokenStaking";
  }

  function version()
  public pure override
  returns (string memory) {
    return "1.1.0";
  }

  using MathLib for uint256;
  using TransferLib for address;
  using AddressArrayLib for address[];
  using UnstakedRecordArrayLib for UnstakedRecord[];

  error CannotRestake();
  error InvalidUnlockWaitingPeriod();
  error NoClaimableRewards();
  error NoStakedRecordFound();
  error NoUnstakedRecordFound();
  error StakedAmountDeductionFailed();
  error StakedAmountInsufficientBalance(address account, UnlockWaitingPeriod, uint256 balance, uint256 value);

  uint256 private _amountPerWeight;
  uint256 private _stakedTotalWeight;
  mapping(UnlockWaitingPeriod => uint256) private _stakedTotalAmountOf;
  mapping(address account => uint256) private _stakedTotalWeightOf;
  mapping(address account => mapping(UnlockWaitingPeriod => uint256)) private _stakedAmountOf;
  mapping(address account => UnstakedRecord[]) private _unstakedRecordsOf;

  mapping(address token => uint256 amount) private _accRewardPerWeightOf;
  mapping(address account => mapping(address token => uint256)) private _rewardDebtOf;
  mapping(address account => mapping(address token => uint256)) private _claimedRewardOf;
  address[] private _rewardTokens;

  function initialize(
    address initialVotingEscrow,
    address initialGovToken,
    address[] memory initialRewardTokens
  )
  public
  initializer {
    initialize();
    _setVotingEscrow(initialVotingEscrow);
    _setGovToken(initialGovToken);
    _setRewardTokens(initialRewardTokens);
  }

  function _authorizeUpdateVotingEscrow(address sender)
  internal view override(UseVotingEscrow) onlyOwner {}

  function _authorizeUpdateGovToken(address sender)
  internal view override(UseGovToken) onlyOwner {}

  function _setGovToken(address newGovToken)
  internal override(UseGovToken) {
    (bool success, bytes memory result) = newGovToken.staticcall(
      abi.encodeWithSignature("decimals()")
    );
    if (!success) revert InvalidToken();
    _amountPerWeight = MathLib.unsafePow(10, abi.decode(result, (uint8)));
    super._setGovToken(newGovToken);
  }

  function _stakedAmountIncrease(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private {
    _stakedAmountOf[account][unlockWaitingPeriod] = _stakedAmountOf[account][unlockWaitingPeriod].unsafeAdd(amount);
    _stakedTotalAmountOf[unlockWaitingPeriod] = _stakedTotalAmountOf[unlockWaitingPeriod].unsafeAdd(amount);
  }

  function _stakedAmountDecrease(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private {
    _stakedAmountOf[account][unlockWaitingPeriod] = _stakedAmountOf[account][unlockWaitingPeriod].unsafeSub(amount);
    _stakedTotalAmountOf[unlockWaitingPeriod] = _stakedTotalAmountOf[unlockWaitingPeriod].unsafeSub(amount);
  }

  function _stakedWeightUpdate(address account, uint256 newWeight)
  private {
    uint256 oldWeight = _stakedTotalWeightOf[account];
    _stakedTotalWeightOf[account] = newWeight;
    if (oldWeight > newWeight) {
      _stakedTotalWeight = _stakedTotalWeight.unsafeSub(oldWeight.unsafeSub(newWeight));
    } else if (oldWeight < newWeight) {
      _stakedTotalWeight = _stakedTotalWeight.unsafeAdd(newWeight.unsafeSub(oldWeight));
    }
  }

  function _rewardDebtIncrease(address account, uint256 weight)
  private {
    address[] memory rewardTokens_ = _rewardTokens;
    uint256 length = rewardTokens_.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address token = rewardTokens_[i];
      _rewardDebtOf[account][token] = _rewardDebtOf[account][token].unsafeAdd(
        weight.unsafeMul(_accRewardPerWeightOf[token])
      );
    }
  }

  function _rewardDebtDecrease(address account, uint256 weight)
  private {
    address[] memory rewardTokens_ = _rewardTokens;
    uint256 length = rewardTokens_.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address token = rewardTokens_[i];
      uint256 reward = _getTokenReward(account, token, weight);
      if (reward > 0) {
        _claim(account, token, reward);
      }
      _rewardDebtOf[account][token] = _rewardDebtOf[account][token].unsafeSub(
        weight.unsafeMul(_accRewardPerWeightOf[token])
      );
    }
  }

  function _checkStakedAmount(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private view {
    uint256 stakedAmount_ = _stakedAmountOf[account][unlockWaitingPeriod];
    if (stakedAmount_ == 0) revert NoStakedRecordFound();
    if (stakedAmount_ < amount) revert StakedAmountInsufficientBalance(account, unlockWaitingPeriod, stakedAmount_, amount);
  }

  function _mintStakingCertificate(address account, uint256 amount)
  private {
    IVotingEscrow(votingEscrow()).mint(account, amount);
  }

  function _burnStakingCertificate(address account, uint256 amount)
  private {
    IVotingEscrow(votingEscrow()).burn(account, amount);
  }

  function stake(UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  external {
    if (unlockWaitingPeriod == UnlockWaitingPeriod.NONE) revert InvalidUnlockWaitingPeriod();
    if (amount == 0) revert InvalidAmount();
    address account = msg.sender;
    account.transferToContract(govToken(), amount);
    _mintStakingCertificate(account, amount);
    _stake(account, unlockWaitingPeriod, amount);
  }

  function stake(
    UnlockWaitingPeriod unlockWaitingPeriod,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    if (unlockWaitingPeriod == UnlockWaitingPeriod.NONE) revert InvalidUnlockWaitingPeriod();
    if (amount == 0) revert InvalidAmount();
    address account = msg.sender;
    account.transferToContract(govToken(), amount, nonce, deadline, signature);
    _mintStakingCertificate(account, amount);
    _stake(account, unlockWaitingPeriod, amount);
  }

  function _stake(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private {
    _stakedAmountIncrease(account, unlockWaitingPeriod, amount);
    uint256 oldWeight = _stakedTotalWeightOf[account];
    uint256 newWeight = _calcWeight(account);
    if (newWeight > oldWeight) {
      uint256 weight = newWeight.unsafeSub(oldWeight);
      _rewardDebtIncrease(account, weight);
    }
    _stakedWeightUpdate(account, newWeight);
    emit Staked(account, unlockWaitingPeriod, amount);
  }

  function unstake(UnlockWaitingPeriod unlockWaitingPeriod)
  external {
    address account = msg.sender;
    uint256 amount = _stakedAmountOf[account][unlockWaitingPeriod];
    _checkStakedAmount(account, unlockWaitingPeriod, amount);
    _burnStakingCertificate(account, amount);
    _unstake(account, unlockWaitingPeriod, amount);
    _unstakedRecordsOf[account].add(
      UnstakedRecord(unlockWaitingPeriod, amount, 0)
    );
  }

  function unstake(UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  external {
    address account = msg.sender;
    _checkStakedAmount(account, unlockWaitingPeriod, amount);
    _burnStakingCertificate(account, amount);
    _unstake(account, unlockWaitingPeriod, amount);
    _unstakedRecordsOf[account].add(
      UnstakedRecord(unlockWaitingPeriod, amount, 0)
    );
  }

  function _unstake(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private {
    _stakedAmountDecrease(account, unlockWaitingPeriod, amount);
    uint256 oldWeight = _stakedTotalWeightOf[account];
    uint256 newWeight = _calcWeight(account);
    if (newWeight < oldWeight) {
      uint256 weight = oldWeight.unsafeSub(newWeight);
      _rewardDebtDecrease(account, weight);
    }
    _stakedWeightUpdate(account, newWeight);
    emit Unstaked(account, unlockWaitingPeriod, amount);
  }

  function restake(uint256 index)
  external {
    address account = msg.sender;
    if (index >= _unstakedRecordsOf[account].length) revert NoUnstakedRecordFound();
    UnstakedRecord memory record = _unstakedRecordsOf[account][index];
    if (block.timestamp > record.unlockTime) revert CannotRestake();

    _unstakedRecordsOf[account].remove(index);
    _mintStakingCertificate(account, record.amount);
    _stake(account, record.unlockWaitingPeriod, record.amount);
  }

  function extendUnlockWaitingPeriod(UnlockWaitingPeriod from, UnlockWaitingPeriod to)
  external {
    if (to == UnlockWaitingPeriod.NONE) revert InvalidUnlockWaitingPeriod();
    if (from >= to) revert InvalidUnlockWaitingPeriod();

    address account = msg.sender;
    uint256 amount = _stakedAmountOf[account][from];
    _checkStakedAmount(account, from, amount);

    _unstake(account, from, amount);
    _stake(account, to, amount);
  }

  function extendUnlockWaitingPeriod(UnlockWaitingPeriod from, UnlockWaitingPeriod to, uint256 amount)
  external {
    if (to == UnlockWaitingPeriod.NONE) revert InvalidUnlockWaitingPeriod();
    if (from >= to) revert InvalidUnlockWaitingPeriod();

    address account = msg.sender;
    _checkStakedAmount(account, from, amount);

    _unstake(account, from, amount);
    _stake(account, to, amount);
  }

  function withdraw()
  external {
    address account = msg.sender;
    UnstakedRecord[] memory records = _unstakedRecordsOf[account].removeByUnlocked();
    uint256 length = records.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      UnstakedRecord memory record = records[i];
      account.transferFromContract(govToken(), record.amount);
      emit Withdrawn(account, record.unlockWaitingPeriod, record.amount);
    }
  }

  function deductStakedAmountAndTransfer(address account, uint256 amount, address custodian)
  public
  onlyVotingEscrow {
    uint256 remainingAmount = amount;
    remainingAmount = _deductStakedAmount(account, UnlockWaitingPeriod.WEEK, remainingAmount);
    if (remainingAmount > 0) remainingAmount = _deductStakedAmount(account, UnlockWaitingPeriod.WEEK12, remainingAmount);
    if (remainingAmount > 0) revert StakedAmountDeductionFailed();
    custodian.transferFromContract(govToken(), amount);
  }

  function batchDeductStakedAmountAndTransfer(address[] calldata accounts, uint256[] calldata amounts, address custodian)
  external
  onlyVotingEscrow {
    uint256 length = accounts.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      deductStakedAmountAndTransfer(accounts[i], amounts[i], custodian);
    }
  }

  function _deductStakedAmount(address account, UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private
  returns (uint256 remainingAmount) {
    uint256 stakedAmount_ = _stakedAmountOf[account][unlockWaitingPeriod];
    if (stakedAmount_ >= amount) {
      _unstake(account, unlockWaitingPeriod, amount);
      remainingAmount = 0;
    } else {
      _unstake(account, unlockWaitingPeriod, stakedAmount_);
      remainingAmount = amount.unsafeSub(stakedAmount_);
    }
    return remainingAmount;
  }

  function stakedAmount()
  external view
  returns (uint256) {
    uint256 stakedTotalAmount;
    uint256 length = uint256(type(UnlockWaitingPeriod).max).unsafeInc();
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      UnlockWaitingPeriod unlockWaitingPeriod = UnlockWaitingPeriod(i);
      if (unlockWaitingPeriod == UnlockWaitingPeriod.NONE) continue;
      stakedTotalAmount = stakedTotalAmount.unsafeAdd(_stakedTotalAmountOf[unlockWaitingPeriod]);
    }
    return stakedTotalAmount;
  }

  function stakedAmount(UnlockWaitingPeriod unlockWaitingPeriod)
  external view
  returns (uint256) {
    return _stakedTotalAmountOf[unlockWaitingPeriod];
  }

  function stakedAmount(address account)
  external view
  returns (uint256) {
    uint256 stakedTotalAmount;
    uint256 length = uint256(type(UnlockWaitingPeriod).max).unsafeInc();
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      UnlockWaitingPeriod unlockWaitingPeriod = UnlockWaitingPeriod(i);
      if (unlockWaitingPeriod == UnlockWaitingPeriod.NONE) continue;
      stakedTotalAmount = stakedTotalAmount.unsafeAdd(_stakedAmountOf[account][unlockWaitingPeriod]);
    }
    return stakedTotalAmount;
  }

  function stakedAmount(address account, UnlockWaitingPeriod unlockWaitingPeriod)
  external view
  returns (uint256) {
    return _stakedAmountOf[account][unlockWaitingPeriod];
  }

  function stakedWeight()
  external view
  returns (uint256) {
    return _stakedTotalWeight;
  }

  function stakedWeight(address account)
  external view
  returns (uint256) {
    return _stakedTotalWeightOf[account];
  }

  function unstakedRecords(address account)
  external view
  returns (UnstakedRecord[] memory) {
    return _unstakedRecordsOf[account];
  }

  function unstakedRecords(address account, UnlockWaitingPeriod unlockWaitingPeriod)
  external view
  returns (UnstakedRecord[] memory) {
    return _unstakedRecordsOf[account].findByUnlockWaitingPeriod(unlockWaitingPeriod);
  }

  function rewardTokens()
  external view
  returns (address[] memory) {
    return _rewardTokens;
  }

  function setRewardTokens(address[] memory tokens)
  external
  onlyOwner {
    _setRewardTokens(tokens);
  }

  function _setRewardTokens(address[] memory tokens)
  private {
    // Reset accumulated reward per weight of removed reward tokens
    address[] memory rewardTokens_ = _rewardTokens;
    uint256 length = rewardTokens_.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      address token = rewardTokens_[i];
      if (!tokens.includes(token)) {
        _accRewardPerWeightOf[token] = 0;
      }
    }
    _rewardTokens = tokens;
    emit RewardTokenSet(tokens);
  }

  function distribute()
  external payable {
    _distribute(address(0), msg.value);
  }

  function distribute(address token, uint256 amount)
  external {
    _distribute(token, amount);
  }

  function _distribute(address token, uint256 amount)
  private {
    address sender = msg.sender;
    sender.transferToContract(token, amount);
    emit Distributed(sender, token, amount);

    uint256 stakedTotalWeight = _stakedTotalWeight;
    if (stakedTotalWeight > 0 && _rewardTokens.includes(token)) {
      _accRewardPerWeightOf[token] = _accRewardPerWeightOf[token].unsafeAdd(
        amount.unsafeDiv(stakedTotalWeight)
      );
    }
  }

  function accRewardPerWeight()
  external view
  returns (uint256) {
    return _accRewardPerWeightOf[address(0)];
  }

  function accRewardPerWeight(address token)
  external view
  returns (uint256) {
    return _accRewardPerWeightOf[token];
  }

  function rewardDebt(address account)
  external view
  returns (uint256) {
    return _rewardDebtOf[account][address(0)];
  }

  function rewardDebt(address account, address token)
  external view
  returns (uint256) {
    return _rewardDebtOf[account][token];
  }

  function correctRewardDebt(address[] calldata accounts)
  external
  onlyOwner {
    uint256 length = accounts.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      _correctRewardDebt(accounts[i], address(0));
    }
  }

  function correctRewardDebt(address[] calldata accounts, address token)
  external
  onlyOwner {
    uint256 length = accounts.length;
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      _correctRewardDebt(accounts[i], token);
    }
  }

  function _correctRewardDebt(address account, address token)
  private {
    uint256 weight = _stakedTotalWeightOf[account];
    uint256 maxRewardDebt = weight.unsafeMul(_accRewardPerWeightOf[token]);
    uint256 rewardDebt_ = _rewardDebtOf[account][token];
    if (rewardDebt_ > maxRewardDebt) {
      _rewardDebtOf[account][token] = maxRewardDebt;
    }
  }

  function claimedRewards(address account)
  external view
  returns (uint256) {
    return _claimedRewardOf[account][address(0)];
  }

  function claimedRewards(address account, address token)
  external view
  returns (uint256) {
    return _claimedRewardOf[account][token];
  }

  function unclaimedRewards(address account)
  external view
  returns (uint256) {
    return _getTokenReward(account, address(0), _stakedTotalWeightOf[account]);
  }

  function unclaimedRewards(address account, address token)
  external view
  returns (uint256) {
    return _getTokenReward(account, token, _stakedTotalWeightOf[account]);
  }

  function claim()
  external {
    address account = msg.sender;
    address token = address(0);
    uint256 reward = _getTokenReward(account, token, _stakedTotalWeightOf[account]);
    if (reward == 0) revert NoClaimableRewards();
    _claim(account, token, reward);
  }

  function claim(address token)
  external {
    address account = msg.sender;
    uint256 reward = _getTokenReward(account, token, _stakedTotalWeightOf[account]);
    if (reward == 0) revert NoClaimableRewards();
    _claim(account, token, reward);
  }

  function _claim(address account, address token, uint256 reward)
  private {
    _rewardDebtOf[account][token] = _rewardDebtOf[account][token].unsafeAdd(reward);
    _claimedRewardOf[account][token] = _claimedRewardOf[account][token].unsafeAdd(reward);
    account.transferFromContract(token, reward);
    emit Claimed(account, token, reward);
  }

  function _getTokenReward(address account, address token, uint256 weight)
  private view
  returns (uint256) {
    uint256 stakedTotalWeight = _stakedTotalWeightOf[account];
    uint256 rewardDebt_ = stakedTotalWeight > 0
      ? _rewardDebtOf[account][token].mulDiv(weight, stakedTotalWeight)
      : 0;
    return weight.unsafeMul(_accRewardPerWeightOf[token]).sub(rewardDebt_);
  }

  function _calcWeight(address account)
  private view
  returns (uint256) {
    uint256 stakedTotalWeight;
    uint256 length = uint256(type(UnlockWaitingPeriod).max).unsafeInc();
    for (uint256 i = 0; i < length; i = i.unsafeInc()) {
      UnlockWaitingPeriod unlockWaitingPeriod = UnlockWaitingPeriod(i);
      if (unlockWaitingPeriod == UnlockWaitingPeriod.NONE) continue;
      uint256 amount = _stakedAmountOf[account][unlockWaitingPeriod];
      uint256 weight = _getWeight(unlockWaitingPeriod, amount);
      stakedTotalWeight = stakedTotalWeight.unsafeAdd(weight);
    }
    return stakedTotalWeight;
  }

  function _getWeight(UnlockWaitingPeriod unlockWaitingPeriod, uint256 amount)
  private view
  returns (uint256) {
    uint256 weight = amount.unsafeDiv(_amountPerWeight);
    return unlockWaitingPeriod == UnlockWaitingPeriod.WEEK12 ? weight.unsafeMul(2) : weight;
  }
}
