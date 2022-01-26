pragma solidity 0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IBank.sol";
import "./IPriceOracle.sol";
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
    using SafeMath for uint;
    address public oracleAddress;
    address public tokenAddress;
    mapping(address => uint) private hakBalanceOf;
    mapping(address => uint) private ethBalanceOf;
    mapping(address => UserDeposit[]) private hakDepositArray;
    mapping(address => UserDeposit[]) private ethDepositArray;
    mapping(address => uint) private ethBalanceBorrowed;
    mapping(address => UserLoan[]) private ethLoansArray;

    constructor(address _oracleAddress, address _tokenAddress) {
      oracleAddress = _oracleAddress;
      tokenAddress = _tokenAddress;
    }

    struct UserDeposit {
      uint amountDeposited;
      uint blockNumber;
    }

    struct UserLoan {
      uint amountBorrowed;
      uint blockNumber;
      uint colateralAmount;
    }

    receive() external payable {

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
    function deposit(address token, uint amount) payable external override returns (bool) {

      require((tokenAddress == token) || (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), "token not supported");
      require(amount > 0, "amount should be greater than 0");

      if(tokenAddress == token) {
        hakBalanceOf[msg.sender] = hakBalanceOf[msg.sender].add(amount);
        UserDeposit memory deposit = UserDeposit(amount, block.number);
        hakDepositArray[msg.sender].push(deposit);

        emit Deposit(
            msg.sender, // account of user who deposited
            token, // token that was deposited
            amount // amount of token that was deposited
        );

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
      } else if (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE == token) {

        ethBalanceOf[msg.sender] = ethBalanceOf[msg.sender].add(amount);                        
        UserDeposit memory deposit = UserDeposit(amount, block.number);
        ethDepositArray[msg.sender].push(deposit);

        emit Deposit(
            msg.sender, // account of user who deposited
            token, // token that was deposited
            amount // amount of token that was deposited
        );
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
    function withdraw(address token, uint amount) external override returns (uint) {
      require((tokenAddress == token) || (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), "token not supported");

      if((tokenAddress == token)) {

        require(0 < hakBalanceOf[msg.sender], "no balance");
        require(amount <= hakBalanceOf[msg.sender], "amount exceeds balance");

        (uint amountDepositedToTransfer, uint interestAccrued) = calculateWithdraw(amount, hakDepositArray[msg.sender]);

        
        hakBalanceOf[msg.sender] = hakBalanceOf[msg.sender].sub(amountDepositedToTransfer);

        uint total = amountDepositedToTransfer.add(interestAccrued);
        IERC20(tokenAddress).approve(address(this), total);
        IERC20(tokenAddress).transferFrom(address(this), msg.sender, total);

        emit Withdraw(
          msg.sender, // account of user who withdrew funds
          token, // token that was withdrawn
          total // amount of token that was withdrawn
        );

      } else if (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE == token) {
        require(0 < ethBalanceOf[msg.sender], "no balance");
        require(amount <= ethBalanceOf[msg.sender], "amount exceeds balance");

        (uint amountDepositedToTransfer, uint interestAccrued)  = calculateWithdraw(amount, ethDepositArray[msg.sender]);

        uint total = amountDepositedToTransfer.add(interestAccrued);

        ethBalanceOf[msg.sender] = ethBalanceOf[msg.sender].sub(amountDepositedToTransfer);

        emit Withdraw(
          msg.sender, // account of user who withdrew funds
          token, // token that was withdrawn
          total // amount of token that was withdrawn
        );

        (bool sent, bytes memory data) = payable(msg.sender).call{value: total}("");
        require(sent, "Failed to send Ether");
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
    function borrow(address token, uint amount) external override returns (uint) {
      require(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE == token, "incorrect token");
      require(amount >= 0 , "invalid input");

      (uint totalExcludingInterest, uint interest) = checkBalance(tokenAddress, msg.sender);
      uint hakBalance = totalExcludingInterest.add(interest);

      require(hakBalance > 0, "no collateral deposited");

      UserLoan[] memory userLoansArray = ethLoansArray[msg.sender];
      // the sum of loans of user + interest
      uint loansBalance = checkLoans(token, msg.sender);

      IPriceOracle oracle = IPriceOracle(oracleAddress);
      uint hakPrice = oracle.getVirtualPrice(tokenAddress);

      uint hakBalanceInEther = hakBalance.mul(hakPrice);

      if(amount > 0) {

      // (deposits[account] + accruedInterest[account]) * 10000 / (borrowed[account] + owedInterest[account]) >= 15000.
      uint collateralRatio = hakBalanceInEther.mul(10000).div(amount.add(loansBalance)).div(1000000000000000000);
      
      require(collateralRatio >= 15000, "borrow would exceed collateral ratio");

      UserLoan memory loan = UserLoan(amount,block.number,collateralRatio);
      UserLoan[] storage userLoanArray = ethLoansArray[msg.sender];
      userLoanArray.push(loan);

      emit Borrow(
          msg.sender, // account who borrowed the funds
          token, // token that was borrowed
          amount, // amount of token that was borrowed
          collateralRatio // collateral ratio for the account, after the borrow
      );

      msg.sender.transfer(amount);
      return collateralRatio;

      } else if(amount == 0){

        // [(deposited + deposit interests) * 10000 / (borrowed + borrowed interests) + toBorrow] >= 15000
 
        uint toBorrow = hakBalance.mul(10).div(15).sub(loansBalance);
        
        uint collateralRatio = hakBalanceInEther.mul(10000).div(loansBalance.add(toBorrow)).div(1000000000000000000);

        UserLoan memory loan = UserLoan(toBorrow,block.number,collateralRatio);
        UserLoan[] storage userLoanArray = ethLoansArray[msg.sender];
        userLoanArray.push(loan);

        emit Borrow(
            msg.sender, // account who borrowed the funds
            token, // token that was borrowed
            toBorrow, // amount of token that was borrowed
            collateralRatio // collateral ratio for the account, after the borrow
        );

        msg.sender.transfer(toBorrow);
        return collateralRatio;
      }
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
    function repay(address token, uint amount) payable external override returns (uint) {
      require(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE == token, "token not supported");
      uint loansBalance = checkLoans(token, msg.sender);
      require(loansBalance > 0, "nothing to repay");
      
      uint totalDebtExcludingInterest;
      uint totalInterest;
      uint remainingDebt;
      if(amount == 0) {
        // first it is calculated de totalDebt to check if the payment is correct.
        (totalDebtExcludingInterest, totalInterest) = calculateRemainingDebt(ethLoansArray[msg.sender]);
        remainingDebt = totalDebtExcludingInterest.add(totalInterest);
        require(remainingDebt <= msg.value, "msg.value < amount to repay");
        // the payment is correct so the debt cancelation is done 
        processDebt(amount,ethLoansArray[msg.sender]);
        (totalDebtExcludingInterest, totalInterest) = calculateRemainingDebt(ethLoansArray[msg.sender]);
        remainingDebt = totalDebtExcludingInterest.add(totalInterest);
      } else {

        require(amount <= msg.value, "msg.value < amount to repay");
        processDebt(amount,ethLoansArray[msg.sender]);
        (totalDebtExcludingInterest, totalInterest) = calculateRemainingDebt(ethLoansArray[msg.sender]);
        remainingDebt = totalDebtExcludingInterest;

      }

      emit Repay(
          msg.sender, // accout which repaid the loan
          token, // token that was borrowed and repaid
          remainingDebt // amount that still remains to be paid (including interest)
      );

      return totalDebtExcludingInterest;
    }
     
    /**
     * The purpose of this function is to allow so called keepers to collect bad
     * debt, that is in case the collateral ratio goes below 150% for any loan. 
     * @param token - the address of the token used as collateral for the loan. 
     * @param account - the account that took out the loan that is now undercollateralized.
     * @return - true if the liquidation was successful, otherwise revert.
     */
    function liquidate(address token, address account) payable external override returns (bool) {
      require((tokenAddress == token), "token not supported");
      require(account != msg.sender, "cannot liquidate own position");

      uint collateralRatio = checkCollateralRatio(token, account);

      require(collateralRatio < 15000, "healty position");

      UserLoan[] storage userLoanArray = ethLoansArray[account];

      
      (uint totalExcludingInterest, uint interest) = checkBalance(token, account);

      uint collateral = totalExcludingInterest.add(interest);
      uint hakBalance = totalExcludingInterest.add(interest);

      uint loansBalance = checkLoans(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, account);

      (uint totalDebtExcludingInterest, uint totalInterest) = calculateRemainingDebt(ethLoansArray[account]);

      processDebt(0, userLoanArray);
      
      // AssertionError: Expected "15454500000000000000" to be equal 15004500000000000000
      emit Liquidate(
          msg.sender, // account which performs the liquidation  
          account, // account which is liquidated
          token, // token which was used as collateral
                                          // for the loan (not the token borrowed)
          totalExcludingInterest, // amount of collateral token which is sent to the liquidator
          10 // amount of borrowed token that is sent back to the
                                // liquidator in case the amount that the liquidator
                                // sent for liquidation was higher than the debt of the liquidated account
      );

      IERC20(token).approve(address(this), collateral);
      IERC20(token).transferFrom(address(this), msg.sender, collateral);

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
    function getCollateralRatio(address token, address account) view external override returns (uint) {
      uint MAX_INT = type(uint).max;
      uint loansBalance = checkLoans(token, account);

      if(loansBalance > 0){
        uint result = checkCollateralRatio(token, account);
        return result;
      } else {
        return MAX_INT;
      }
    }

    function checkCollateralRatio(address token, address account) view internal returns (uint) {
      // (deposits[account] + accruedInterest[account]) * 10000 / (borrowed[account] + owedInterest[account]) >= 15000.
      uint loansBalance = checkLoans(token, account);
      IPriceOracle oracle = IPriceOracle(oracleAddress);
      uint price = oracle.getVirtualPrice(tokenAddress);
      (uint totalExcludingInterest, uint interest) = checkBalance(token, account);

      uint hakBalance = totalExcludingInterest.add(interest);

      uint hakBalanceInEther = hakBalance.mul(price);
      uint collateralRatio = hakBalanceInEther.mul(10000).div(loansBalance).div(1000000000000000000);      

      return collateralRatio;
    }

    function checkLoans(address token, address account) view internal returns (uint) {
      require((tokenAddress == token) || (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), "token not supported");
      uint total;
      uint totalInterestAccrued;      
      UserLoan[] memory userLoansArray = ethLoansArray[account];
      uint totalBorrowed;
      for (uint index = 0; index < userLoansArray.length; index++) {
        if(userLoansArray[index].amountBorrowed == 0) {
          continue;
        }
          totalBorrowed = totalBorrowed.add(userLoansArray[index].amountBorrowed);

          uint interest_accrued_per_block = userLoansArray[index].amountBorrowed.mul(5).div(10000);
          uint blockDelta = (block.number.sub(userLoansArray[index].blockNumber));
          uint interest_accrued_fixed = blockDelta * interest_accrued_per_block;
          totalInterestAccrued = totalInterestAccrued.add(interest_accrued_fixed);              

          // marco el deposito como procesado
          UserLoan memory userLoan = userLoansArray[index];
          userLoan.amountBorrowed = 0;
      }
      return totalBorrowed.add(totalInterestAccrued);

    }

    /**
     * The purpose of this function is to return the balance that the caller 
     * has in their own account for the given token (including interest).
     * @param token - the address of the token for which the balance is computed.
     * @return - the value of the caller's balance with interest, excluding debts.
     */
    function getBalance(address token) view external override returns (uint) {
      (uint totalExcludingInterest, uint interest) = checkBalance(token, msg.sender);

      uint balance = totalExcludingInterest.add(interest);
      return balance;
    }

    function processDebt(uint amount, UserLoan[] storage userLoanArray) internal returns (uint, uint){
      require(amount >= 0, "invalid amount value");
      uint totalToRepay = amount;
      uint totalInterestToPay;


      if(amount >0 ) {
        for (uint index = 0; index < userLoanArray.length; index++) {
          if(userLoanArray[index].amountBorrowed == 0) {
            continue;
          }

          uint blockDelta = (block.number.sub(userLoanArray[index].blockNumber));
          uint interest_accrued_per_block = userLoanArray[index].amountBorrowed.mul(5).div(10000);
          uint interest_accrued_fixed = blockDelta * interest_accrued_per_block;

          uint debtIncludingInterest = userLoanArray[index].amountBorrowed.add(interest_accrued_fixed);

          if(totalToRepay >= debtIncludingInterest) {
            totalToRepay = totalToRepay.sub(debtIncludingInterest);
            userLoanArray[index].amountBorrowed = 0;
          } else {
            userLoanArray[index].amountBorrowed = debtIncludingInterest.sub(totalToRepay);
            break;
          }

          if(totalToRepay == 0) {
            break;
          }
        }

        // return the amount still left to pay for this loan, excluding interest
      } else {
        for (uint index = 0; index < userLoanArray.length; index++) {
          userLoanArray[index].amountBorrowed = 0;
        }
      }
    }

    function calculateRemainingDebt(UserLoan[] memory userLoanArray) view internal returns (uint, uint){
      uint totalDebtLeftExludingInterest;
      uint totalInterest;

      for (uint index = 0; index < userLoanArray.length; index++) {
        if(userLoanArray[index].amountBorrowed == 0) {
          continue;
        }

        uint blockDelta = (block.number.sub(userLoanArray[index].blockNumber));
        uint interest_accrued_per_block = userLoanArray[index].amountBorrowed.mul(5).div(10000);
        uint interest_accrued_fixed = blockDelta * interest_accrued_per_block;

        totalDebtLeftExludingInterest = totalDebtLeftExludingInterest.add(userLoanArray[index].amountBorrowed);
        totalInterest = totalInterest.add(interest_accrued_fixed);
      }

      return (totalDebtLeftExludingInterest, totalInterest);
    }

    function calculateWithdraw(uint amount, UserDeposit[] storage userDepositArray) internal returns (uint, uint){     
        require(amount >= 0, "invalid amount value");

        if(amount != 0) {
          // tengo que sacar el amount adecuado, recorriendo cada deposito y calculando el interes sobre cada depósito
          // es probable que tenga que sacar parte de un deposito y dejar depositado el resto del mismo depósito
          // voy a utilizar FIFO (first in first out), osea que retiro los depósitos que se hicieron
          // al principio
          // UserDeposit[] storage userDepositArray = depositArray[msg.sender];

          uint total;
          uint totalInterestAccrued;
          for (uint index = 0; index < userDepositArray.length; index++) {
            if(userDepositArray[index].amountDeposited == 0) {
              continue;
            }
            uint val = total.add(userDepositArray[index].amountDeposited);

            if((val <= amount)) {
              total = total.add(userDepositArray[index].amountDeposited);

              uint interest_accrued_per_block = userDepositArray[index].amountDeposited.mul(3).div(10000);
              uint blockDelta = (block.number.sub(userDepositArray[index].blockNumber));
              uint interest_accrued_fixed = blockDelta * interest_accrued_per_block;
              
              totalInterestAccrued = totalInterestAccrued.add(interest_accrued_fixed);              

              // marco el deposito como procesado
              UserDeposit storage userDeposit = userDepositArray[index];
              userDeposit.amountDeposited = 0;
            } else {
              uint diff = amount.sub(total);
              total = total.add(diff);
              UserDeposit storage userDeposit = userDepositArray[index];

              userDeposit.amountDeposited = userDeposit.amountDeposited.sub(diff);

              uint interest_accrued_per_block = diff.mul(3).div(10000);
              uint blockDelta = (block.number.sub(userDepositArray[index].blockNumber));
              uint interest_accrued_fixed = blockDelta * interest_accrued_per_block;
              
              totalInterestAccrued = totalInterestAccrued.add(interest_accrued_fixed);

            }
            if(amount == total) {
              // marco el ultipo deposito parcialmente procesado como procesado
              break;
            }
          }
          return (total, totalInterestAccrued);

        } else {
          // retiramos todo
          uint total;
          uint totalInterestAccrued;

          for (uint index = 0; index < userDepositArray.length; index++) {
            if(userDepositArray[index].amountDeposited == 0) {
              continue;
            }
              total = total.add(userDepositArray[index].amountDeposited);

              uint interest_accrued_per_block = userDepositArray[index].amountDeposited.mul(3).div(10000);
              uint blockDelta = (block.number.sub(userDepositArray[index].blockNumber));
              uint interest_accrued_fixed = blockDelta * interest_accrued_per_block;
              
              totalInterestAccrued = totalInterestAccrued.add(interest_accrued_fixed);              

              // marco el deposito como procesado
              UserDeposit storage userDeposit = userDepositArray[index];
              userDeposit.amountDeposited = 0;
          }
          return (total, totalInterestAccrued);
        }      
  }
  function checkBalance(address token, address account) view internal returns (uint, uint) {
      require((tokenAddress == token) || (token == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), "token not supported");
      uint total;
      uint totalInterestAccrued;
      UserDeposit[] memory userDepositArray;

      if(tokenAddress == token) {
         userDepositArray = hakDepositArray[account];
      } else if (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE == token) {
        userDepositArray = ethDepositArray[account];
      }

      for (uint index = 0; index < userDepositArray.length; index++) {
        if(userDepositArray[index].amountDeposited == 0) {
          continue;
        }
        total = total.add(userDepositArray[index].amountDeposited);

        uint interest_accrued_per_block = userDepositArray[index].amountDeposited.mul(3).div(10000);
        uint blockDelta = (block.number.sub(userDepositArray[index].blockNumber));
        uint interest_accrued_fixed = blockDelta * interest_accrued_per_block;
        
        totalInterestAccrued = totalInterestAccrued.add(interest_accrued_fixed);              
        // marco el deposito como procesado
        // UserDeposit memory userDeposit = userDepositArray[index];
        // userDeposit.amountDeposited = 0;
      }
      // uint returnValue = total.add(totalInterestAccrued);
      return (total, totalInterestAccrued);
  }
}