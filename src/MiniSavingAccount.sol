// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol";

error AssetNotSupported();

contract MiniSavingAccount is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint256)) public borrowRates;
    mapping(address => mapping(address => uint256)) public healthFactors;

    function configureAsset(
        address lendingAsset,
        address borrowingAsset,
        uint256 borrowRate,
        uint256 healthFactor
    ) external onlyOwner {
        borrowRates[lendingAsset][borrowingAsset] = borrowRate;
        healthFactors[lendingAsset][borrowingAsset] = healthFactor;
    }

    function configureAssetsBatched(
        address[] calldata _lendingAssets,
        address[] calldata _borrowingAssets,
        uint256[] calldata _borrowRates,
        uint256[] calldata _healthFactors
    ) external onlyOwner {
        for (uint256 i = 0; i < _lendingAssets.length; i++) {
            borrowRates[_lendingAssets[i]][_borrowingAssets[i]] = _borrowRates[
                i
            ];
            healthFactors[_lendingAssets[i]][
                _borrowingAssets[i]
            ] = _healthFactors[i];
        }
    }
}
