// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Math} from "openzeppelin/contracts/utils/math/Math.sol";
import {MintableERC20} from "./mock/MintableERC20.sol";
import {MiniSavingAccount, AssetNotSupported, LiquidationUnavailable, PeriodTooShort} from "src/MiniSavingAccount.sol";

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

    function testSetCollateralRate(
        address asset1,
        address asset2,
        uint256 rate
    ) public {
        vm.startPrank(alice);
        account.setCollateralRate(asset1, asset2, rate);
        vm.stopPrank();

        assertEq(account.collateralRates(asset1, asset2), rate);
    }

    function testSetCollateralRateBatched() public {
        address[] memory asset1 = new address[](2);
        asset1[0] = address(usd);
        asset1[1] = address(eur);

        address[] memory asset2 = new address[](2);
        asset2[0] = address(usd);
        asset2[1] = address(eur);

        uint256[] memory rate = new uint256[](2);
        rate[0] = 1 ether;
        rate[1] = 2 ether;

        vm.startPrank(alice);

        account.setCollateralRateBatched(asset1, asset2, rate);
        vm.stopPrank();

        for (uint256 i = 0; i < asset1.length; i++) {
            assertEq(account.collateralRates(asset1[i], asset2[i]), rate[i]);
        }
    }

    function testSetDailyLendingRate(uint256 amount) public {
        vm.startPrank(alice);
        account.setDailyLendingRate(address(usd), amount);
        vm.stopPrank();

        assertEq(account.lendingRatesDaily(address(usd)), amount);
    }

    function testSetDailyLendingRateBatched() public {
        address[] memory asset = new address[](2);
        asset[0] = address(usd);
        asset[1] = address(eur);

        uint256[] memory rate = new uint256[](2);
        rate[0] = 1 ether;
        rate[1] = 2 ether;

        vm.startPrank(alice);
        account.setDailyLendingRateBatched(asset, rate);
        vm.stopPrank();

        for (uint256 i = 0; i < asset.length; i++) {
            assertEq(account.lendingRatesDaily(asset[i]), rate[i]);
        }
    }

    function testBorrow() public {
        (
            uint256 depositAmount,
            uint256 borrowAmount,
            uint256 lendingRate,
            uint256 collateralRate,
            uint256 borrowingPeriod
        ) = _createParams();

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

    function testBorrowRevertAssetNotSupported(
        uint256 borrowAmount,
        uint256 borrowPeriod
    ) public {
        borrowPeriod = bound(borrowPeriod, 7 days, type(uint256).max);

        vm.expectRevert(AssetNotSupported.selector);
        account.borrow(address(usd), borrowAmount, address(eur), borrowPeriod);
    }

    function testBorrowRevertPeriodTooShort(
        uint256 borrowAmount,
        uint256 borrowPeriod
    ) public {
        borrowPeriod = bound(borrowPeriod, 0, 7 days - 1);

        vm.expectRevert(PeriodTooShort.selector);
        account.borrow(address(usd), borrowAmount, address(usd), borrowPeriod);
    }

    function testRepay() public {
        (
            uint256 depositAmount,
            uint256 borrowAmount,
            uint256 lendingRate,
            uint256 collateralRate,
            uint256 borrowingPeriod
        ) = _createParams();

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
        (
            uint256 depositAmount,
            uint256 borrowAmount,
            uint256 lendingRate,
            uint256 collateralRate,
            uint256 borrowingPeriod
        ) = _createParams();

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
        testBorrow();

        MiniSavingAccount.BorrowInfo memory borrowInfo = account
            .getBorrowingInfo(0);

        vm.warp(borrowInfo.returDateTimestamp - 1);
        vm.expectRevert(LiquidationUnavailable.selector);
        account.liquidate(0);
    }

    function _createParams()
        internal
        pure
        returns (
            uint256 depositAmount,
            uint256 borrowAmount,
            uint256 ledningRate,
            uint256 collateralRate,
            uint256 borrowingPeriod
        )
    {
        depositAmount = 3 ether;
        borrowAmount = 1 ether;
        ledningRate = 1 ether / 100;
        collateralRate = (16 * 1 ether) / 10;
        borrowingPeriod = 365 days;
    }
}
