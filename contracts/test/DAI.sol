// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAI is ERC20 {
  constructor() ERC20("DAI", "DAI") {}

  function decimals()
  public pure override
  returns (uint8) {
    return 18;
  }

  function mint(uint256 amount)
  external {
    _mint(msg.sender, amount);
  }
}
