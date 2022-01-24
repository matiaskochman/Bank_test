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
      console.log("111111111111111111");
      console.log("withdraw executing amount: ", amount.div(1000000000000000000));
      console.log("");

      if((tokenAddress == token)) {
        require(0 < hakBalanceOf[msg.sender], "no balance");
        require(amount <= hakBalanceOf[msg.sender], "amount exceeds balance");
        
        if(amount != 0) {
          // tengo que sacar el amount adecuado, recorriendo cada deposito y calculando el interes sobre cada depósito
          // es probable que tenga que sacar parte de un deposito y dejar depositado el resto del mismo depósito
          // voy a utilizar FIFO (first in first out), osea que retiro los depósitos que se hicieron
          // al principio
          UserDeposit[] storage userDepositArray = depositArray[msg.sender];

          uint total;
          uint totalInterestAccrued;
          for (uint256 index = 0; index < userDepositArray.length; index++) {
            if(!userDepositArray[index].active) {
              continue;
            }
            console.log("deposit number: ", index);
            console.log("deposit amount: ", userDepositArray[index].amountDeposited.div(1000000000000000000));
            uint val = total.add(userDepositArray[index].amountDeposited);

            if((val <= amount)) {              
              console.log("caso 1");
              // la suma del total de depositos procesados + el proximo deposito procesado
              // es menor al total que quiero retirar
              total = total.add(userDepositArray[index].amountDeposited);

              uint interest_accrued_per_block = userDepositArray[index].amountDeposited.mul(3).div(10000);
              uint delta1 = (block.number.sub(userDepositArray[index].blockNumber));
              uint interest_accrued_fixed = delta1 * interest_accrued_per_block;
              
              totalInterestAccrued = totalInterestAccrued.add(interest_accrued_fixed);              

              // marco el deposito como procesado
              UserDeposit storage userDeposit = userDepositArray[index];
              userDeposit.active = false;
            } else {
              console.log("caso 2");
              // la suma del total de depositos procesados + el proximo deposito procesado
              // es mayor al total que quiero retirar.
              // Tengo que procesar parte del próximo deposito y dejar lo que sobra depositado.
              uint diff = amount.sub(total);

              // uint aux = amount.sub(total);
              total = total.add(diff);
              UserDeposit storage userDeposit = userDepositArray[index];

              userDeposit.amountDeposited = userDeposit.amountDeposited.sub(diff);

              uint256 interest_accrued_per_block = diff.mul(3).div(10000);
              uint delta1 = (block.number.sub(userDepositArray[index].blockNumber));
              uint256 interest_accrued_fixed = delta1 * interest_accrued_per_block;
              
              totalInterestAccrued = totalInterestAccrued.add(interest_accrued_fixed);

            }
            console.log("total: ", total.div(1000000000000000000));
            console.log("total interest: ", totalInterestAccrued.div(1000000000000000));
            console.log("");
            if(amount == total) {
              // marco el ultipo deposito parcialmente procesado como procesado
              break;
            }
          }
          if(total>0) {
            console.log(" ");
            console.log("end of iteration");
            console.log("total: ", total.div(1000000000000000000));
            console.log("total interest: ", totalInterestAccrued.div(1000000000000000));
            console.log("111111111111111111");
            console.log(" ");
            console.log(" ");
            console.log(" ");
            console.log(" ");
            console.log(" ");
            
          }
          // require(total>0, "account is empty, cannot withdraw");
        } else {
          console.log("retiramos todo el hak"); 
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