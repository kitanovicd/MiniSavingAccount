// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MintableERC20} from "./mock/MintableERC20.sol";
import {MiniSavingAccount, AssetNotSupported, LiquidationUnavailable} from "src/MiniSavingAccount.sol";
import {console} from "forge-std/console.sol";
import {Math} from "openzeppelin/contracts/utils/math/Math.sol";

contract MiniSavingAccountTest is Test {
    address alice;
    address bob;

    MintableERC20 public usd;
    MintableERC20 public eur;

    MiniSavingAccount public account;

    function setUp() public {
        alice = makeAddr("Alice");
        bob = makeAddr("Bob");

        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);

        usd = new MintableERC20("United Stated Dollar", "USD");
        eur = new MintableERC20("Euro", "EUR");

        usd.mint(alice, 1000 ether);
        usd.mint(bob, 1000 ether);
        eur.mint(alice, 1000 ether);
        eur.mint(bob, 1000 ether);

        vm.startPrank(alice);
        account = new MiniSavingAccount();
        vm.stopPrank();
    }

    function testDeposit(uint256 amount) public {
        amount = bound(amount, 0, usd.balanceOf(alice));

        uint256 aliceBalanceBefore = usd.balanceOf(alice);

        vm.startPrank(alice);
        usd.approve(address(account), amount);
        account.deposit(address(usd), amount);
        vm.stopPrank();

        uint256 aliceBalanceAfter = usd.balanceOf(alice);

        assertEq(account.balances(address(usd)), amount);
        assertEq(usd.balanceOf(address(account)), amount);
        assertEq(aliceBalanceBefore - aliceBalanceAfter, amount);
    }

    function testWithdraw(
        uint256 depositAmount,
        uint256 withdrawAmount
    ) public {
        depositAmount = bound(depositAmount, 0, usd.balanceOf(alice));
        withdrawAmount = bound(withdrawAmount, 0, depositAmount);

        vm.startPrank(alice);
        usd.approve(address(account), depositAmount);
        account.deposit(address(usd), depositAmount);
        vm.stopPrank();

        uint256 aliceBalanceBefore = usd.balanceOf(alice);

        vm.startPrank(alice);
        account.withdraw(address(usd), withdrawAmount);
        vm.stopPrank();

        uint256 aliceBalanceAfter = usd.balanceOf(alice);

        assertEq(
            account.balances(address(usd)),
            depositAmount - withdrawAmount
        );
        assertEq(
            usd.balanceOf(address(account)),
            depositAmount - withdrawAmount
        );
        assertEq(aliceBalanceAfter - aliceBalanceBefore, withdrawAmount);
    }

    function testSetCollateralRate(uint256 amount) public {
        vm.startPrank(alice);
        account.setCollateralRate(address(usd), address(eur), amount);
        vm.stopPrank();

        assertEq(account.collateralRates(address(usd), address(eur)), amount);
    }

    function testSetDailyLendingRate(uint256 amount) public {
        vm.startPrank(alice);
        account.setDailyLendingRate(address(usd), amount);
        vm.stopPrank();

        assertEq(account.lendingRatesDaily(address(usd)), amount);
    }

    function testBorrow() public {
        uint256 borrowingPeriod = 365 days;
        uint256 depositAmount = 3 ether;
        uint256 borrowAmount = 1 ether;
        uint256 lendingRate = 1 ether / 100;
        uint256 collateralRate = (16 * 1 ether) / 10;

        vm.startPrank(alice);
        account.setCollateralRate(address(usd), address(eur), collateralRate);
        account.setDailyLendingRate(address(usd), lendingRate);

        usd.approve(address(account), depositAmount);
        account.deposit(address(usd), depositAmount);
        vm.stopPrank();

        vm.startPrank(bob);

        uint256 bobUsdBalanceBefore = usd.balanceOf(bob);
        uint256 bobEurBalanceBefore = eur.balanceOf(bob);

        uint256 returnAmount = borrowAmount +
            (lendingRate * borrowingPeriod) /
            1 ether;
        uint256 collateralAmount = (returnAmount * collateralRate) / 1 ether;

        eur.approve(address(account), collateralAmount);
        uint256 borrowIndex = account.borrow(
            address(usd),
            borrowAmount,
            address(eur),
            borrowingPeriod
        );

        vm.stopPrank();

        uint256 bobUsdBalanceAfter = usd.balanceOf(bob);
        uint256 bobEurBalanceAfter = eur.balanceOf(bob);

        assertEq(borrowIndex, 0);
        assertEq(account.balances(address(usd)), depositAmount - borrowAmount);
        assertEq(account.balances(address(eur)), 0);
        assertEq(eur.balanceOf(address(account)), collateralAmount);
        assertEq(usd.balanceOf(address(account)), depositAmount - borrowAmount);
        assertEq(bobUsdBalanceAfter - bobUsdBalanceBefore, borrowAmount);
        assertEq(bobEurBalanceBefore - bobEurBalanceAfter, collateralAmount);

        MiniSavingAccount.BorrowInfo memory borrowInfo = account
            .getBorrowingInfo(0);

        assertEq(borrowInfo.borrowAsset, address(usd));
        assertEq(borrowInfo.collateralAsset, address(eur));
        assertEq(borrowInfo.borrowAmount, borrowAmount);
        assertEq(borrowInfo.collateralAmount, collateralAmount);
        assertEq(borrowInfo.returnAmount, returnAmount);
        assertEq(
            borrowInfo.returDateTimestamp,
            block.timestamp + borrowingPeriod
        );
    }

    function testRepay() public {
        uint256 borrowingPeriod = 365 days;
        uint256 depositAmount = 3 ether;
        uint256 borrowAmount = 1 ether;
        uint256 lendingRate = 1 ether / 100;
        uint256 collateralRate = (16 * 1 ether) / 10;

        vm.startPrank(alice);

        account.setCollateralRate(address(usd), address(eur), collateralRate);
        account.setDailyLendingRate(address(usd), lendingRate);
        usd.approve(address(account), depositAmount);
        account.deposit(address(usd), depositAmount);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 returnAmount = borrowAmount +
            (lendingRate * borrowingPeriod) /
            1 ether;
        uint256 collateralAmount = (returnAmount * collateralRate) / 1 ether;

        eur.approve(address(account), collateralAmount);
        account.borrow(
            address(usd),
            borrowAmount,
            address(eur),
            borrowingPeriod
        );

        usd.approve(address(account), returnAmount);
        account.repay(0);

        vm.stopPrank();

        assertEq(
            account.balances(address(usd)),
            depositAmount - borrowAmount + returnAmount
        );
        assertEq(account.balances(address(eur)), 0);
        assertEq(eur.balanceOf(address(account)), 0);
        assertEq(
            usd.balanceOf(address(account)),
            depositAmount - borrowAmount + returnAmount
        );

        MiniSavingAccount.BorrowInfo memory borrowInfo = account
            .getBorrowingInfo(0);

        assertEq(borrowInfo.collateralAmount, 0);
        assertEq(borrowInfo.returnAmount, 0);
    }

    function testLiquidate() public {
        uint256 borrowingPeriod = 365 days;
        uint256 depositAmount = 3 ether;
        uint256 borrowAmount = 1 ether;
        uint256 lendingRate = 1 ether / 100;
        uint256 collateralRate = (16 * 1 ether) / 10;

        vm.startPrank(alice);

        account.setCollateralRate(address(usd), address(eur), collateralRate);
        account.setDailyLendingRate(address(usd), lendingRate);
        usd.approve(address(account), depositAmount);
        account.deposit(address(usd), depositAmount);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 returnAmount = borrowAmount +
            (lendingRate * borrowingPeriod) /
            1 ether;
        uint256 collateralAmount = (returnAmount * collateralRate) / 1 ether;

        eur.approve(address(account), collateralAmount);
        account.borrow(
            address(usd),
            borrowAmount,
            address(eur),
            borrowingPeriod
        );

        vm.stopPrank();

        vm.warp(block.timestamp + borrowingPeriod + 1);
        account.liquidate(0);

        assertEq(account.balances(address(usd)), depositAmount - borrowAmount);
        assertEq(account.balances(address(eur)), collateralAmount);
        assertEq(usd.balanceOf(address(account)), depositAmount - borrowAmount);
        assertEq(eur.balanceOf(address(account)), collateralAmount);

        MiniSavingAccount.BorrowInfo memory borrowInfo = account
            .getBorrowingInfo(0);

        assertEq(borrowInfo.collateralAmount, 0);
        assertEq(borrowInfo.returnAmount, 0);
    }

    function testLiquidateRevertLiquidationUnavailable() public {
        uint256 borrowingPeriod = 365 days;
        uint256 depositAmount = 3 ether;
        uint256 borrowAmount = 1 ether;
        uint256 lendingRate = 1 ether / 100;
        uint256 collateralRate = (16 * 1 ether) / 10;

        vm.startPrank(alice);

        account.setCollateralRate(address(usd), address(eur), collateralRate);
        account.setDailyLendingRate(address(usd), lendingRate);
        usd.approve(address(account), depositAmount);
        account.deposit(address(usd), depositAmount);

        vm.stopPrank();
        vm.startPrank(bob);

        uint256 returnAmount = borrowAmount +
            (lendingRate * borrowingPeriod) /
            1 ether;
        uint256 collateralAmount = (returnAmount * collateralRate) / 1 ether;

        eur.approve(address(account), collateralAmount);
        account.borrow(
            address(usd),
            borrowAmount,
            address(eur),
            borrowingPeriod
        );

        vm.stopPrank();

        vm.warp(block.timestamp + borrowingPeriod - 1);
        vm.expectRevert(LiquidationUnavailable.selector);
        account.liquidate(0);
    }
}
