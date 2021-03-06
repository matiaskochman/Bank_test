
pragma solidity 0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HAKTest is ERC20 {

   uint256 public constant STARTING_SUPPLY = 1e30;
   constructor() ERC20("HAKToken", "HAK") {
      _mint(msg.sender, STARTING_SUPPLY);
   }
}