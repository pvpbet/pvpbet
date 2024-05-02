// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BetGovToken is ERC20, ERC20Pausable, Ownable {
  constructor () ERC20("PVPBetGovToken", "PVPB") Ownable(msg.sender) {
    _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
  }

  function pause()
  public
  onlyOwner {
    _pause();
  }

  function unpause()
  public
  onlyOwner {
    _unpause();
  }

  function _update(address from, address to, uint256 value)
  internal override(ERC20, ERC20Pausable) {
    super._update(from, to, value);
  }
}
