// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

error AssetNotSupported();
error LiquidationUnavailable();

contract MiniSavingAccount is Ownable {
    using SafeERC20 for IERC20;

    struct BorrowInfo {
        address borrowAsset;
        address collateralAsset;
        uint256 borrowAmount;
        uint256 collateralAmount;
        uint256 returnAmount;
        uint256 returDateTimestamp;
    }

    mapping(address => uint256) public balances;
    mapping(address => uint256) public lendingRatesDaily;
    mapping(address => mapping(address => uint256)) public collateralRates;

    BorrowInfo[] public borrowings;

    function deposit(address asset, uint256 amount) external {
        balances[asset] += amount;
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address asset, uint256 amount) external {
        balances[asset] -= amount;
        IERC20(asset).safeTransfer(msg.sender, amount);
    }

    function borrow(
        address borrowAsset,
        uint256 borrowAmount,
        address collateralAsset,
        uint256 period
    ) external returns (uint256) {
        uint256 collateralRate = collateralRates[borrowAsset][collateralAsset];

        if (collateralRate == 0) {
            revert AssetNotSupported();
        }

        uint256 returnAmount = borrowAmount +
            (lendingRatesDaily[borrowAsset] * period) /
            1 ether;

        uint256 collateralAmount = (returnAmount * collateralRate) / 1 ether;

        borrowings.push(
            BorrowInfo({
                borrowAsset: borrowAsset,
                collateralAsset: collateralAsset,
                borrowAmount: borrowAmount,
                collateralAmount: collateralAmount,
                returnAmount: returnAmount,
                returDateTimestamp: block.timestamp + period
            })
        );

        balances[borrowAsset] -= borrowAmount;

        IERC20(borrowAsset).safeTransfer(msg.sender, borrowAmount);
        IERC20(collateralAsset).safeTransferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );

        return borrowings.length - 1;
    }

    function repay(uint256 index) external {
        BorrowInfo storage borrowInfo = borrowings[index];

        balances[borrowInfo.borrowAsset] += borrowInfo.returnAmount;

        IERC20(borrowInfo.borrowAsset).safeTransferFrom(
            msg.sender,
            address(this),
            borrowInfo.returnAmount
        );
        IERC20(borrowInfo.collateralAsset).safeTransfer(
            msg.sender,
            borrowInfo.collateralAmount
        );

        borrowInfo.collateralAmount = 0;
        borrowInfo.returnAmount = 0;
    }

    function liquidate(uint256 index) external {
        BorrowInfo storage borrowInfo = borrowings[index];

        if (borrowInfo.returDateTimestamp >= block.timestamp) {
            revert LiquidationUnavailable();
        }

        balances[borrowInfo.collateralAsset] += borrowInfo.collateralAmount;

        borrowInfo.collateralAmount = 0;
        borrowInfo.returnAmount = 0;
    }

    function setCollateralRate(
        address lendingAsset,
        address borrowingAsset,
        uint256 borrowRate
    ) external onlyOwner {
        collateralRates[lendingAsset][borrowingAsset] = borrowRate;
    }

    function setDailyLendingRate(
        address asset,
        uint256 lendingRate
    ) external onlyOwner {
        lendingRatesDaily[asset] = lendingRate;
    }

    function getBorrowingInfo(
        uint256 index
    ) external view returns (BorrowInfo memory) {
        return borrowings[index];
    }
}
