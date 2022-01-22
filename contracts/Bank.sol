pragma solidity 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IBank.sol";
import "hardhat/console.sol";

interface IERC20 {
    function totalSupply() external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

contract Bank is IBank {
    using SafeMath for uint256;
    uint constant REWARD_PER_BLOCK = 3 * 10**14; // 3% each 100 blocks is 0.0003 per block. 0.0003 X 10000 = 3
    // uint public MAX_VALUE = 2**256 -1;
    uint constant MULTIPLIER_FOR_REWARD_CALCULATION = 10000;
    address public oracleAddress;
    address public tokenAddress;
    mapping(address => uint) public hakBalanceOf;
    mapping(address => uint) public ethBalanceOf;
    mapping(address => UserDeposit[]) public depositArray;

    constructor(address _oracleAddress, address _tokenAddress) {
      oracleAddress = _oracleAddress;
      tokenAddress = _tokenAddress;
    }

    struct UserDeposit {
      string coin;
      uint amountDeposited;
      uint blockNumber;
      bool active;
    }

    /**
     * The purpose of this function is to allow end-users to deposit a given 
     * token amount into their bank account.
     * @param token - the address of the token to deposit. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token to deposit is ETH.
     * @param amount - the amount of the given token to deposit.
     * @return - true if the deposit was successful, otherwise revert.
     */
    function deposit(address token, uint256 amount) payable external override returns (bool) {

      require((tokenAddress == token) || (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), "token not supported");
      require(amount > 0, "amount should be greater than 0");

      if(tokenAddress == token) {

        hakBalanceOf[msg.sender] = hakBalanceOf[msg.sender].add(amount);
        UserDeposit memory deposit = UserDeposit("HAK", amount, block.number, true);
        depositArray[msg.sender].push(deposit);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);

      } else if (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE == token) {

        ethBalanceOf[msg.sender] = ethBalanceOf[msg.sender].add(amount);                        
        UserDeposit memory deposit = UserDeposit("ETH", amount, block.number, true);
        depositArray[msg.sender].push(deposit);

      }
      return true;
    }

    /**
     * The purpose of this function is to allow end-users to withdraw a given 
     * token amount from their bank account. Upon withdrawal, the user must
     * automatically receive a 3% interest rate per 100 blocks on their deposit.
     * @param token - the address of the token to withdraw. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token to withdraw is ETH.
     * @param amount - the amount of the given token to withdraw. If this param
     *                 is set to 0, then the maximum amount available in the 
     *                 caller's account should be withdrawn.
     * @return - the amount that was withdrawn plus interest upon success, 
     *           otherwise revert.
     */
    function withdraw(address token, uint256 amount) external override returns (uint256) {
      require((tokenAddress == token) || (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), "token not supported");

      if((tokenAddress == token)) {
        require(0 < hakBalanceOf[msg.sender], "no balance");
        require(amount <= hakBalanceOf[msg.sender], "amount exceeds balance");

        if(amount <= hakBalanceOf[msg.sender]) {
          if(amount != 0) {
            // tengo que sacar el amount adecuado, recorriendo cada deposito y calculando el interes sobre cada depósito
            // es probable que tenga que sacar parte de un deposito y dejar depositado el resto del mismo depósito
            // voy a utilizar FIFO (first in first out), osea que retiro los depósitos que se hicieron
            // al principio
            UserDeposit[] memory userDepositArray = depositArray[msg.sender];

            uint256 total;
            uint256 totalInterestAccrued;
            for (uint256 index = 0; index < userDepositArray.length; index++) {
              if(!userDepositArray[index].active) {
                continue;
              }

              uint val = total.add(userDepositArray[index].amountDeposited);
              if(val <= amount) {
                total = total.add(userDepositArray[index].amountDeposited);
                uint256 interest_accrued_per_block = userDepositArray[index].amountDeposited.mul(3).div(10000);
                uint delta1 = (block.number.sub(userDepositArray[index].blockNumber));
                uint256 interest_accrued_fixed = delta1 * interest_accrued_per_block;
                
                totalInterestAccrued = totalInterestAccrued.add(interest_accrued_fixed);

                console.log("delta1: ", delta1);
                console.log("userDepositArray[index].amountDeposited: ", userDepositArray[index].amountDeposited);
                console.log("userDepositArray[index].blockNum: ", userDepositArray[index].blockNumber);
                console.log("interest_accrued_per_block: ", interest_accrued_per_block);
                console.log("interest_accrued_fixed: ", interest_accrued_fixed);
                console.log("REWARD_PER_BLOCK: ", REWARD_PER_BLOCK);

                UserDeposit memory userDeposit = userDepositArray[index];
                userDeposit.active = false;
              } else {
                uint aux = amount.sub(total);

                uint256 interest_accrued_per_block = userDepositArray[index].amountDeposited.mul(3).div(10000);
                uint delta1 = (block.number.sub(userDepositArray[index].blockNumber));
                uint256 interest_accrued_fixed = delta1 * interest_accrued_per_block;
                
                totalInterestAccrued = totalInterestAccrued.add(interest_accrued_fixed);

                console.log("delta2: ", delta1);
                console.log("userDepositArray[index].amountDeposited: ", userDepositArray[index].amountDeposited);
                console.log("userDepositArray[index].blockNum: ", userDepositArray[index].blockNumber);
                console.log("interest_accrued_per_block: ", interest_accrued_per_block);
                console.log("interest_accrued_fixed: ", interest_accrued_fixed);
                console.log("REWARD_PER_BLOCK: ", REWARD_PER_BLOCK);

                break;
              }
            }
            
            console.log("total: ", total);
            console.log("amount: ", amount);
            console.log("interest accrued: ", totalInterestAccrued);
            console.log("retiramos amount of hak");
          } else {
            console.log("retiramos todo el hak"); 
          }
        } else {
          console.log("quiere retirar mas hak del depositado, malechor, delincuente");
        }

      } else if (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE == token) {
        require(0 < ethBalanceOf[msg.sender], "no balance");
        require(amount <= ethBalanceOf[msg.sender], "amount exceeds balance");
        if(amount <= ethBalanceOf[msg.sender]) {

          if(amount != 0) {
            console.log("retiramos amount of eth");
          } else {
            console.log("retiramos todo el eth"); 
          }

        } else {
          console.log("quiere retirar mas eth del depositado, malechor, delincuente");
        }
      }
      
    }
      
    /**
     * The purpose of this function is to allow users to borrow funds by using their 
     * deposited funds as collateral. The minimum ratio of deposited funds over 
     * borrowed funds must not be less than 150%.
     * @param token - the address of the token to borrow. This address must be
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, otherwise  
     *                the transaction must revert.
     * @param amount - the amount to borrow. If this amount is set to zero (0),
     *                 then the amount borrowed should be the maximum allowed, 
     *                 while respecting the collateral ratio of 150%.
     * @return - the current collateral ratio.
     */
    function borrow(address token, uint256 amount) external override returns (uint256) {
      return 1;
    }
     
    /**
     * The purpose of this function is to allow users to repay their loans.
     * Loans can be repaid partially or entirely. When replaying a loan, an
     * interest payment is also required. The interest on a loan is equal to
     * 5% of the amount lent per 100 blocks. If the loan is repaid earlier,
     * or later then the interest should be proportional to the number of 
     * blocks that the amount was borrowed for.
     * @param token - the address of the token to repay. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token is ETH.
     * @param amount - the amount to repay including the interest.
     * @return - the amount still left to pay for this loan, excluding interest.
     */
    function repay(address token, uint256 amount) payable external override returns (uint256) {
      return 1;
    }
     
    /**
     * The purpose of this function is to allow so called keepers to collect bad
     * debt, that is in case the collateral ratio goes below 150% for any loan. 
     * @param token - the address of the token used as collateral for the loan. 
     * @param account - the account that took out the loan that is now undercollateralized.
     * @return - true if the liquidation was successful, otherwise revert.
     */
    function liquidate(address token, address account) payable external override returns (bool) {
      return true;
    }
 
    /**
     * The purpose of this function is to return the collateral ratio for any account.
     * The collateral ratio is computed as the value deposited divided by the value
     * borrowed. However, if no value is borrowed then the function should return 
     * uint256 MAX_INT = type(uint256).max
     * @param token - the address of the deposited token used a collateral for the loan. 
     * @param account - the account that took out the loan.
     * @return - the value of the collateral ratio with 2 percentage decimals, e.g. 1% = 100.
     *           If the account has no deposits for the given token then return zero (0).
     *           If the account has deposited token, but has not borrowed anything then 
     *           return MAX_INT.
     */
    function getCollateralRatio(address token, address account) view external override returns (uint256) {
      return 1;
    }

    /**
     * The purpose of this function is to return the balance that the caller 
     * has in their own account for the given token (including interest).
     * @param token - the address of the token for which the balance is computed.
     * @return - the value of the caller's balance with interest, excluding debts.
     */
    function getBalance(address token) view external override returns (uint256) {
      require((tokenAddress == token) || (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), "token not supported");
      if(tokenAddress == token) {
        return hakBalanceOf[msg.sender];
      } else if (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE == token) {
        console.log("balance eth");
        return ethBalanceOf[msg.sender];
      }

      return 1;
    }
}