# MiniSavingAccount Smart Contract
This smart contract implements a mini saving account that allows users to deposit assets, borrow against their deposits, liquidate and repay their borrowings. It supports different assets and owner needs to configure lending and collateral rates for each asset before borrowing is enabled.

## Features

The MiniSavingAccount smart contract provides the following features:

1. **Deposit**: Users can deposit assets into their savings account by calling the ***deposit*** function. The deposited assets are stored in the contract's balance and can be withdrawn later. User must approve smart contract on specific asset and amount before calling this function, otherwise transaction will revert. Please note that smart contract is written that way that anyone can deposit asset into any saving account but only owner of saving account that withdraw them. This means that non owner address has no reason to deposit assets into owner's saving account. However, this transaction will not revert because there is no security risk for owner's funds - only benefits. Also someone maybe wants to send gift to owner directly to his saving account instead of sending funds to personal wallet address.

2. **Withdraw**: Users can withdraw their deposited assets by calling the ***withdraw*** function. The specified amount of assets will be transferred back to the user's address. Function does not perfomed any balance checks. If owner wants to withdraw more assets then he has into saving account or wants to withdraw assets that are not liquidated transaction will revert because of insufficient funds or overflow.

3. **Borrow**: Users can borrow assets by providing collateral. The ***borrow*** function allows users to specify the borrowing asset, borrowing amount, collateral asset, and borrowing period. Minimum borrowing period is 7 days and can be subject of discussion. The function calculates the return amount based on the borrowing amount and lending rates, and the required collateral amount based on the collateral rate. The collateral asset is transferred to the contract, and the borrowing asset is transferred to the borrower. 

4. **Repay**: Borrowers can repay their borrowings by calling the ***repay*** function and specifying the index of borrowing position that he wants to repay. The borrowed assets are transferred back to the contract, and the collateral assets are transferred back to the borrower.

5. **Liquidate**: If a borrower fails to repay their borrowings within the specified borrowing period, the collateral can be liquidated by calling the ***liquidate*** function. The collateral assets stay in contract but now user can withdraw them. Also contract storage is updated that way that if borrower wants to repay already liquidated borrowing position transaction will pass but user will not receive any funds and contract will not take any funds away from him. This can be subject of discussion. Contract can be changed to revert in that case so user does not spend his ETH on full transaction fees. Also anyone can liquidate but will not be incentivised for that.

6. **Setting Collateral Rates**: The contract owner can set the collateral rate for specific borrowing and lending assets by calling the ***setCollateralRate***  or ***setCollateralRateBatched*** function.

7. **Setting Daily Lending Rates**: The contract owner can set the daily lending rate for specific assets by calling the ***setDailyLendingRate*** or ***setDailyLendingRateBatched*** function.

8. **Get Borrowing Info**: Users can retrieve information about a specific borrowing by calling the ***getBorrowingInfo*** function and providing the borrowing index.

## Explanation

Some more simple smart contract could be implemented. For example, user could only deposit and withdraw assets into/from his saving account and to claim rewards based on timestamp. Claiming rewards can be implemented to only mint specific tokens to users address. However, this is the most simple approach possible and I decided to implement something more realistic so user can earn rewards in correct manner which makes solution correct from perspective of science of economy.

This smart contract is based on Aave V2 lending/borrowing machanism but much more simplified. 

## Example

Let's say that Alice wants to put 1000 usd tokens into her saving account. She can do that by calling ***deposit*** function and let's say that Alice wants to enable borrowing of her usd and she accepts eur as collateral. First Alice needs to define lending rate of 1 usd token. Lending rate should be defined on daily level. This means that if Alice wants to earn 15% / year on her usd she need set lending rate of usd to 15 * 10^18 / 365; Afteer that Alice needs to configure collateral rate between usd and eur. Let's assume that collateral rate between this two tokens will be 1,8. This means that Alice needs to set collateral rate to 1,8 * 10^18 = 18 * 10^17. Now this will be explained in one more detail example.

Alice deposits 1000 usd token and configure lending and collateral rates like it is explained. Bob borrows 100 usd token on 365 days period. This means that Bob needs to return to Alice 15% on top of borrowed amount which means 115 usd tokens. If Bob wants to put eur as collateral he needs to put 115 * 1,8 = 207 eur tokens. When Bob repays his borrowing position he will receive his collateral back.

## Tests

Tests are written to cover as much scenarios as possible. Some test are fuzz test and some of them are not. Reason why some tests are not fuzz is next - It was really hard to properly bound all fuzz parameters such as *depositAmount*, *borrowAmount*, *borrowPeriod*, *collateralRate* and *lendingRate*. Because of that some tests are not fuzz tests. **This should never happen in production ready code!**

**Note that broadcast is pushed to main branch. This is standard practice because all developers need to share last deployment broadcast.**

## Improvement
This smart contract can be improved to handle multiple people depositing and borrowing into the same smart contract. Also this can be improved by writing ***MiniSavingAccountFactory*** smart contract. This smart contract would be responsible for deploying mini saving accounts for users and handling them. In that case ***MiniSavingAccountFactory*** will be owner of all saving account contract and because of that ***MiniSavingAccount*** contract should not be ownable no more but should handle owner inside constructor. Third way to improve this is to impelement ***SmartSavingAccountRouter*** smart contract who will find for each borrow best lending place like Balancer's ***SmartOfferRouter*** is doing.
## Usage

1. Clone the repository and position yourself in it:
```bash
git clone git@github.com:kitanovicd/MiniSavingAccount.git
cd MiniSavingAccount
```

2. Compile smart contract:
```bash
forge build
```

3. Run tests:
```bash
forge test
```

4. Configure .env file by following .env.example

5. Deploy smart contract:
```bash
chmod +x ./script/deploy.sh
./script/deploy.sh
```
