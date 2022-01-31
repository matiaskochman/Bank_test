# Advanced Sample Hardhat Project

This project demonstrates an advanced Hardhat use case, integrating other tools commonly used alongside Hardhat in the ecosystem.

The project comes with a sample contract, a test for that contract, a sample script that deploys that contract, and an example of a task implementation, which simply lists the available accounts. It also comes with a variety of other tools, preconfigured to work with the project code.

Try running some of the following tasks:

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat coverage
npx hardhat run scripts/deploy.js
node scripts/deploy.js
npx eslint '**/*.js'
npx eslint '**/*.js' --fix
npx prettier '**/*.{json,sol,md}' --check
npx prettier '**/*.{json,sol,md}' --write
npx solhint 'contracts/**/*.sol'
npx solhint 'contracts/**/*.sol' --fix
```

# Etherscan verification

To try out Etherscan verification, you first need to deploy a contract to an Ethereum network that's supported by Etherscan, such as Ropsten.

In this project, copy the .env.example file to a file named .env, and then edit it to fill in the details. Enter your Etherscan API key, your Ropsten node URL (eg from Alchemy), and the private key of the account which will send the deployment transaction. With a valid .env file in place, first deploy your contract:

```shell
hardhat run --network ropsten scripts/deploy.js
```

Then, copy the deployment address and paste it in to replace `DEPLOYED_CONTRACT_ADDRESS` in this command:

```shell
npx hardhat verify --network ropsten DEPLOYED_CONTRACT_ADDRESS "Hello, Hardhat!"
```



The following technical test has been adapted from a security hackaton in order to demonstrate the technical skills of our senior developers.

## The Challenge

For this challenge you must develop the project according to the guidelines. 

1. Create a public repository in Github or any other similar service
2. Commit regularly to check your progress
3. Email us the repository URL
4. Deadline is on January 13th 10pm UTC -5. However, the earliest the better.

## The Project

The goal of this phase is to develop one smart contract that conforms to a given interface and passes a given test suite. After these contracts are implemented, they must be deployed on the [Goerli test network](https://goerli.net/). Here are the main points and rules

1. Build a smart contract system that can be used as a [lending platform](https://en.wikipedia.org/wiki/Decentralized_finance).
2. Tropykus provides the [interface](https://www.notion.so/Functional-Requirements-IBank-Interface-HAK-Token-and-Oracle-Addresses-ce22fe19a5a6461d90dabd89790e7657) that MUST be used for the implementation.
3. Tropykus provides the address of an [ERC20](https://eips.ethereum.org/EIPS/eip-20) contract called the [HAK token](https://goerli.etherscan.io/address/0xbefeed4cb8c6dd190793b1c97b72b60272f3ea6c), which can be deposited in the bank as collateral for borrowing ETH. You can get Goerli ETH from [https://faucet.paradigm.xyz/](https://faucet.paradigm.xyz/)
4. Tropykus will provide a test suite to verify that the implemented code functions properly. Teams that do not pass all tests will be penalized i.e. their final HAK token balance will be divided by the number of tests failed + 1.
5. You MUST deploy their smart contract(s) on the Goerli test network by the deadline.

## Functional Requirements, IBank Interface, HAK Token and Oracle Addresses

<aside>
💡 **DISCLAIMER:** All contracts developed and provided for and during this challenge are not safe and should not be used in production systems!

</aside>

### **Functional Requirements**

In the following text, we use the terms "user" and "bank customer" interchangeably. The following functional requirements must be satisfied by the implementation of the smart contract(s):

1. A bank customer's account is represented by their wallet address.
2. A bank customer must be able to deposit an amount higher than 0 of tokens into their own account. Deposits can be made in HAK and ETH for the purpose of this challenge.
3. A bank customer must be able to withdraw only up to the amount they deposited into their own account + interest accrued.
4. When withdrawing a deposit, the user will automatically receive interest on their deposit of 3% per 100 blocks. If a user withdraws their deposit earlier or later than 100 blocks, they will receive a proportional interest amount.
5. A bank customer must be able to deposit multiple times in the same account and if so, the interest should be accounted for each time deposit and withdraw are called by that user.
6. Interest must not be compounding. This means that interest is earned only on the deposited amount and not on the accumulated interest itself.
7. A bank customer must be able to borrow ETH from the bank using the HAK token as collateral.
8. The minimum collateral ratio for any loan is 150%. This means that the value of HAK tokens deposited by the user taking out the loan (plus interest), divided by the ETH value borrowed by the same user (plus interest), must be greater or equal to 150%, that is: `(deposits[account] + accruedInterest[account]) * 10000 / (borrowed[account] + owedInterest[account]) >= 15000`.
9. If the collateral ratio for an outstanding loan goes below 150%, then anyone must be able to repay the loan and receive the collateral tokens in exchange for repaying the loan. We call this a "liquidation" of the loan. During liquidation, the debt of the borrower must be erased AND the borrower loses their deposit, which is transferred to the liquidator.
10. A borrower must be able to repay their loan in full or partially at any point in time if they have not been liquidated.
11. Repaying a loan involves paying the borrowed amount, plus an interest rate of 5% of the borrowed amount, per 100 blocks.
12. Anyone must be able to check the current collateral ratio of any account at any point in time.
13. Each of the 5 state-changing functions defined in the `IBank` interface must emit the corresponding event defined at the top of the interface with the correct parameters as specified in the code comments for each event. The view function in the interface does not need to emit any event.
14. The constructor of the `Bank` contract that you write MUST have exactly 2 input parameters. The first parameter must be the address of the price oracle contract. The second input parameter must be the address of the HAK token contract.

Function-specific requirements are written in the code comments of the mandatory `IBank` interface below.

### **Non-Functional Requirements**

1. The implementation must use Solidity version 0.7.0, that is `pragma solidity 0.7.0` MUST be at the beginning of the source file.

### **Mandatory Interface**

The following interface must be implemented by the implemented smart contract(s):

```jsx
pragma solidity 0.7.0;

interface IBank {
    struct Account { // Note that token values have an 18 decimal precision
        uint256 deposit;           // accumulated deposits made into the account
        uint256 interest;          // accumulated interest
        uint256 lastInterestBlock; // block at which interest was last computed
    }
    // Event emitted when a user makes a deposit
    event Deposit(
        address indexed _from, // account of user who deposited
        address indexed token, // token that was deposited
        uint256 amount // amount of token that was deposited
    );
    // Event emitted when a user makes a withdrawal
    event Withdraw(
        address indexed _from, // account of user who withdrew funds
        address indexed token, // token that was withdrawn
        uint256 amount // amount of token that was withdrawn
    );
    // Event emitted when a user borrows funds
    event Borrow(
        address indexed _from, // account who borrowed the funds
        address indexed token, // token that was borrowed
        uint256 amount, // amount of token that was borrowed
        uint256 newCollateralRatio // collateral ratio for the account, after the borrow
    );
    // Event emitted when a user (partially) repays a loan
    event Repay(
        address indexed _from, // accout which repaid the loan
        address indexed token, // token that was borrowed and repaid
        uint256 remainingDebt // amount that still remains to be paid (including interest)
    );
    // Event emitted when a loan is liquidated
    event Liquidate(
        address indexed liquidator, // account which performs the liquidation
        address indexed accountLiquidated, // account which is liquidated
        address indexed collateralToken, // token which was used as collateral
                                         // for the loan (not the token borrowed)
        uint256 amountOfCollateral, // amount of collateral token which is sent to the liquidator
        uint256 amountSentBack // amount of borrowed token that is sent back to the
                               // liquidator in case the amount that the liquidator
                               // sent for liquidation was higher than the debt of the liquidated account
    );
    /**
     * The purpose of this function is to allow end-users to deposit a given 
     * token amount into their bank account.
     * @param token - the address of the token to deposit. If this address is
     *                set to 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE then 
     *                the token to deposit is ETH.
     * @param amount - the amount of the given token to deposit.
     * @return - true if the deposit was successful, otherwise revert.
     */
    function deposit(address token, uint256 amount) payable external returns (bool);

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
    function withdraw(address token, uint256 amount) external returns (uint256);
      
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
    function borrow(address token, uint256 amount) external returns (uint256);
     
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
    function repay(address token, uint256 amount) payable external returns (uint256);
     
    /**
     * The purpose of this function is to allow so called keepers to collect bad
     * debt, that is in case the collateral ratio goes below 150% for any loan. 
     * @param token - the address of the token used as collateral for the loan. 
     * @param account - the account that took out the loan that is now undercollateralized.
     * @return - true if the liquidation was successful, otherwise revert.
     */
    function liquidate(address token, address account) payable external returns (bool);
 
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
    function getCollateralRatio(address token, address account) view external returns (uint256);

    /**
     * The purpose of this function is to return the balance that the caller 
     * has in their own account for the given token (including interest).
     * @param token - the address of the token for which the balance is computed.
     * @return - the value of the caller's balance with interest, excluding debts.
     */
    function getBalance(address token) view external returns (uint256);
}
```

### **The HAK token and its price oracle**

- The HAK token is a typical ERC20 token deployed at this address: [https://goerli.etherscan.io/address/0xbefeed4cb8c6dd190793b1c97b72b60272f3ea6c](https://goerli.etherscan.io/address/0xbefeed4cb8c6dd190793b1c97b72b60272f3ea6c)
- In order to get the price of the HAK token in ETH, which will allow you to compute the collateral ratio, use the following `PriceOracle` contract: [https://goerli.etherscan.io/address/0xc3F639B8a6831ff50aD8113B438E2Ef873845552](https://goerli.etherscan.io/address/0xc3F639B8a6831ff50aD8113B438E2Ef873845552)
- The `PriceOracle` contract implements the following simple interface that should be used when implementing the Bank:

```jsx
pragma solidity 0.7.0;

interface IPriceOracle {
    /**
     * The purpose of this function is to retrieve the price of the given token
     * in ETH. For example if the price of a HAK token is worth 0.5 ETH, then
     * this function will return 500000000000000000 (5e17) because ETH has 18 
     * decimals. Note that this price is not fixed and might change at any moment,
     * according to the demand and supply on the open market.
     * @param token - the ERC20 token for which you want to get the price in ETH.
     * @return - the price in ETH of the given token at that moment in time.
     */
    function getVirtualPrice(address token) view external returns (uint256);
}
```

**NOTE:** The `PriceOracle` contract has its code published on Etherscan and it may contain vulnerabilities. Attacking the `PriceOracle` or the HAK token contracts is allowed in Phase 2 of this challenge (see Phase 2 description below).

## Test Suite

The following file should be placed in the test folder of your application

[Bank.ts](https://s3-us-west-2.amazonaws.com/secure.notion-static.com/345ffa4b-da87-480e-9a1a-65970073bdd6/Bank.ts)

```jsx
import { ethers } from "hardhat";
import { Signer } from "ethers";
import chai from 'chai';

import { Bank } from "../typechain-types/Bank";
import { HAKTest } from "../typechain-types/HAKTest";
import { PriceOracleTest } from "../typechain-types/PriceOracleTest";
import { experimentalAddHardhatNetworkMessageTraceHook } from "hardhat/config";
import exp from "constants";

const { expect } = chai;
const { BigNumber } = ethers;

// waffle chai matcher docs
// https://ethereum-waffle.readthedocs.io/en/latest/matchers.html

describe("Bank contract", function () {
  // first signer account is the one to deploy contracts by default
  let owner: Signer;

  let acc1: Signer;
  let acc2: Signer;
  let acc3: Signer;

  let oracle: PriceOracleTest;
  let hak: HAKTest;
  let bank: Bank;

  // bank instances connected to accN
  let bank1: Bank;
  let bank2: Bank;
  let bank3: Bank;

  // hak instances connected to accN
  let hak1: HAKTest;
  let hak2: HAKTest;
  let hak3: HAKTest;

  let ethMagic: string;

  async function mineBlocks(blocksToMine: number) {
    let startBlock = await ethers.provider.getBlockNumber();
    let timestamp = (await ethers.provider.getBlock(startBlock)).timestamp;
    for (let i = 1; i <= blocksToMine; ++i) {
      await ethers.provider.send("evm_mine", [timestamp + i * 13]);
    }
    let endBlock = await ethers.provider.getBlockNumber();
    expect(endBlock).equals(startBlock + blocksToMine);
  }

  beforeEach("deployment setup", async function () {
    [owner, acc1, acc2, acc3] = await ethers.getSigners();
    const oracleFactory = await ethers.getContractFactory("PriceOracleTest");
    const hakFactory = await ethers.getContractFactory("HAKTest");
    const bankFactory = await ethers.getContractFactory("Bank");

    oracle = await oracleFactory.deploy();
    hak = await hakFactory.deploy();

    bank = await bankFactory.deploy(oracle.address, hak.address);
    ethMagic = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

    // provide some tokens/eth to the bank to pay the interest
    let hakAmount = ethers.utils.parseEther("50.0");
    await hak.transfer(bank.address, hakAmount);
    let ethAmount = ethers.utils.parseEther("50.0");
    await bank.deposit(ethMagic, ethAmount, {value: ethAmount});

    bank1 = bank.connect(acc1);
    bank2 = bank.connect(acc2);
    bank3 = bank.connect(acc3);

    hak1 = hak.connect(acc1);
    hak2 = hak.connect(acc2);
    hak3 = hak.connect(acc3);
  });

  describe("deposit", async function () {
    it("unsupported token", async function () {
      await expect(bank.deposit(await acc1.getAddress(), 1337)).to.be.revertedWith("token not supported");
    });

    it("deposit hak", async function () {
      let amount = BigNumber.from(1337);
      let balanceBefore = await hak.balanceOf(await acc1.getAddress());
      await hak.transfer(await acc1.getAddress(), amount);
      await hak1.approve(bank.address, amount);
      expect(await hak.allowance(await acc1.getAddress(), bank.address)).equals(amount);
      await bank1.deposit(hak.address, amount);
      expect(await bank1.getBalance(hak.address)).equals(amount);
      expect(await hak.balanceOf(await acc1.getAddress())).equals(0);
    });

    it("deposit eth", async function () {
      let amountBefore = await ethers.provider.getBalance(bank.address);
      let amount = ethers.utils.parseEther("10.0");
      await bank1.deposit(ethMagic, amount, {value: amount});
      expect(await ethers.provider.getBalance(bank.address)).equals(amountBefore.add(amount));
      expect(await bank1.getBalance(ethMagic)).equals(amount);
    });
  });

  describe("withdraw", async function () {
    it("unsupported token", async function () {
      await expect(bank.withdraw(await acc1.getAddress(), 1337)).to.be.revertedWith("token not supported");
    });

    it("without balance", async function () {
      let amount = BigNumber.from(1337);
      await expect(bank1.withdraw(ethMagic, amount)).to.be.revertedWith("no balance");
      await expect(bank1.withdraw(hak.address, amount)).to.be.revertedWith("no balance");
    });

    it("balance too low", async function () {
      let amount = BigNumber.from(10000);
      await bank1.deposit(ethMagic, amount, {value: amount});
      await expect(bank1.withdraw(ethMagic, amount.add(1000))).to.be.revertedWith("amount exceeds balance");
    });
  });

  describe("interest", async function () {
    it("100 blocks", async function () {
      let amount = BigNumber.from(10000);
      await bank1.deposit(ethMagic, amount, {value: amount});
      await mineBlocks(99);
      await expect(bank1.withdraw(ethMagic, 0))
        .to.emit(bank, "Withdraw")
        .withArgs(await acc1.getAddress(), ethMagic, 10300);
    });

    it("150 blocks", async function () {
      let amount = BigNumber.from(10000);
      await bank1.deposit(ethMagic, amount, {value: amount});
      await mineBlocks(149);
      await expect(bank1.withdraw(ethMagic, 0))
        .to.emit(bank, "Withdraw")
        .withArgs(await acc1.getAddress(), ethMagic, 10450);
        // (1 + 0.03 * 150/100) * 10000
    });

    it("250 blocks", async function () {
      let amount = BigNumber.from(10000);
      await bank1.deposit(ethMagic, amount, {value: amount});
      await mineBlocks(249);
      await expect(bank1.withdraw(ethMagic, 0))
        .to.emit(bank, "Withdraw")
        .withArgs(await acc1.getAddress(), ethMagic, 10750);
        // (1 + 0.03 * 250/100) * 10000
    });

    it("1311 blocks", async function () {
      let amount = BigNumber.from(10000);
      await bank1.deposit(ethMagic, amount, {value: amount});
      await mineBlocks(1310);
      await expect(bank1.withdraw(ethMagic, 0))
        .to.emit(bank, "Withdraw")
        .withArgs(await acc1.getAddress(), ethMagic, 13933);
        // (1 + 0.03 * 1311/100) * 10000
    });

    it("200 blocks in 2 steps", async function () {
      let amount = BigNumber.from(10000);
      // deposit once, wait 100 blocks and check balance
      await bank1.deposit(ethMagic, amount, {value: amount});
      await mineBlocks(100);
      expect(await bank1.getBalance(ethMagic)).equals(10300);

      // deposit again to trigger account update, wait 100 blocks and withdraw all
      await bank1.deposit(ethMagic, amount, {value: amount});
      await mineBlocks(99);
      await expect(bank1.withdraw(ethMagic, 0))
        .to.emit(bank, "Withdraw")
        .withArgs(await acc1.getAddress(), ethMagic,
            10300 // initial deposit + 100 block interest reward
          + 3     // the 1 block where additional funds are deposited
          + 10600 // second deposit + 100 block reward on 20k
        );
    });
  });

  describe("borrow", async function () {
    it("no collateral", async function () {
      let amount = BigNumber.from(1000);
      await expect(bank1.borrow(ethMagic, amount)).to.be.revertedWith("no collateral deposited");
    });

    it("basic borrow", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("10.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.emit(bank, "Borrow")
        .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, 15004);
      expect(await bank1.getCollateralRatio(hak.address, await acc1.getAddress()))
        .equals(15004);
    });

    it("exceed borrow single borrow", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("12.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.be.revertedWith("borrow would exceed collateral ratio");
    });

    it("exceed borrow multiple borrows", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("9.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.emit(bank, "Borrow")
        .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, 16671);
      expect(await bank1.getCollateralRatio(hak.address, await acc1.getAddress()))
        .equals(16671);

      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.be.revertedWith("borrow would exceed collateral ratio");
      expect(await bank1.getCollateralRatio(hak.address, await acc1.getAddress()))
        .equals(16668);
    });

    it("max borrow", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      // there will be a block of interest applied to the collateral which
      // leads to the deviation from 10.0
      let borrowAmount = ethers.utils.parseEther("10.003");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, 0))
        .to.emit(bank, "Borrow")
        .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, 15000);
      expect(await bank1.getCollateralRatio(hak.address, await acc1.getAddress()))
        .equals(15000);
    });

    it("multiple borrows", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("3.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      let collateralRatios = [50015, 25008, 16673];
      for (let i = 0; i < 3; ++i) {
        await expect(bank1.borrow(ethMagic, borrowAmount))
          .to.emit(bank, "Borrow")
          .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, collateralRatios[i]);
      }
      expect(await bank1.getCollateralRatio(hak.address, await acc1.getAddress()))
        .equals(collateralRatios[collateralRatios.length - 1]);
    });

    it("multiple borrows + max borrow", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("3.0");
      let ethBefore = await acc1.getBalance();
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      let collateralRatios = [50015, 25008, 16673];
      for (let i = 0; i < 3; ++i) {
        await expect(bank1.borrow(ethMagic, borrowAmount))
          .to.emit(bank, "Borrow")
          .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, collateralRatios[i]);
      }
      expect(await bank1.getCollateralRatio(hak.address, await acc1.getAddress()))
        .equals(collateralRatios[collateralRatios.length - 1]);

      // now borrow everything that's left
      await expect(bank1.borrow(ethMagic, 0))
        .to.emit(bank, "Borrow");
      expect(await bank1.getCollateralRatio(hak.address, await acc1.getAddress()))
        .equals(15000);

      // make sure we (roughly) received the expected amount of eth
      let ethAfter = await acc1.getBalance();
      let ethBorrowed = ethAfter.sub(ethBefore);
      expect(ethBorrowed).to.be.gte(ethers.utils.parseEther("10.0"));
      expect(ethBorrowed).to.be.lte(
        ethers.utils.parseEther("10.0").add(ethers.utils.parseEther("0.005")));
    });

  });

  describe("repay", async function () {
    it ("nothing to repay", async function () {
      let amount = BigNumber.from(1000);
      await expect(bank1.repay(ethMagic, amount, {value: amount})).to.be.revertedWith("nothing to repay");
    });

    it ("non-ETH token", async function () {
      let amount = BigNumber.from(1000);
      await expect(bank1.repay(hak.address, amount)).to.be.revertedWith("token not supported");
    });

    it ("lower amount sent", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("10.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.emit(bank, "Borrow")
        .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, 15004);
      let amount = BigNumber.from(1000);
      await expect(bank1.repay(ethMagic, amount,  {value: amount.sub(1)})).to.be.revertedWith("msg.value < amount to repay");
    });

    it ("repay full amount", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("10.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.emit(bank, "Borrow")
        .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, 15004);
      let amountDue = borrowAmount.add("5000000000000000")
      await expect(bank1.repay(ethMagic, BigNumber.from(0), {value: amountDue}))
        .to.emit(bank, "Repay")
        .withArgs(await acc1.getAddress(), ethMagic,
        0);
    });

    it ("repay partial amount", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("10.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.emit(bank, "Borrow")
        .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, 15004);
      let amountToRepay = ethers.utils.parseEther("4.0");
      let remainingDebt = await expect(bank1.repay(ethMagic, amountToRepay, { value: amountToRepay}))
        .to.emit(bank, "Repay")
        .withArgs(await acc1.getAddress(), ethMagic,
        borrowAmount.sub(amountToRepay)
        .add(5000000000000000)); // interest for 1 block)
    });
  });

  describe("liquidate", async function () {
    it ("liquidates a different token than HAK", async function () {
      await expect(bank1.liquidate(ethMagic, await acc1.getAddress()))
        .to.be.revertedWith("token not supported");
    });

    it ("liquidates own account", async function () {
      await expect(bank1.liquidate(hak.address, await acc1.getAddress()))
        .to.be.revertedWith("cannot liquidate own position");
    });

    it ("collateral ratio higher than 150%", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("10.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.emit(bank, "Borrow")
        .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, 15004);
      let liquidatorAmount = ethers.utils.parseEther("16.0");
      await expect(bank2.liquidate(hak.address, await acc1.getAddress(), { value: liquidatorAmount}))
        .to.be.revertedWith("healty position");
    });

    it ("collateral ratio lower than 150%", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("10.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.emit(bank, "Borrow")
        .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, 15004);
      await mineBlocks(99);
      let liquidatorEthBalanceBefore = await acc2.getBalance();
      let liquidatorHakBalanceBefore = await hak2.balanceOf(await acc2.getAddress());
      collateralAmount = ethers.utils.parseEther("15.0045");
      let liquidatorAmount = ethers.utils.parseEther("16.0");
      await expect(bank2.liquidate(hak.address, await acc1.getAddress(), { value: liquidatorAmount}))
        .to.emit(bank, "Liquidate")
        .withArgs(
          await acc2.getAddress(),
          await acc1.getAddress(),
          hak.address,
          collateralAmount,
          liquidatorAmount.sub("10500000000000000000")
        );
      let liquidatorEthBalanceAfter = await acc2.getBalance();
      let liquidatorHakBalanceAfter = await hak2.balanceOf(await acc2.getAddress());
      expect(liquidatorEthBalanceBefore.sub(liquidatorEthBalanceAfter))
        .to.gte(BigNumber.from("10500000000000000000"));
      expect(liquidatorHakBalanceAfter.sub(liquidatorHakBalanceBefore))
        .to.equal(collateralAmount);
    });

    it ("collateral ratio lower than 150% but insufficient ETH", async function () {
      let collateralAmount = ethers.utils.parseEther("15.0");
      let borrowAmount = ethers.utils.parseEther("10.0");
      await hak.transfer(await acc1.getAddress(), collateralAmount);
      await hak1.approve(bank.address, collateralAmount);
      await bank1.deposit(hak.address, collateralAmount);
      await expect(bank1.borrow(ethMagic, borrowAmount))
        .to.emit(bank, "Borrow")
        .withArgs(await acc1.getAddress(), ethMagic, borrowAmount, 15004);
      await mineBlocks(99);
      let liquidatorAmount = ethers.utils.parseEther("10.0");
      await expect(bank2.liquidate(hak.address, await acc1.getAddress(), { value: liquidatorAmount}))
        .to.be.revertedWith("insufficient ETH sent by liquidator");
    });
  });
});
```