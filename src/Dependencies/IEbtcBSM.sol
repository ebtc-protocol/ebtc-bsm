// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.29;

interface IEbtcBSM {
    event EscrowUpdated(address indexed oldVault, address indexed newVault);
    event FeeToSellUpdated(uint256 oldFee, uint256 newFee);
    event FeeToBuyUpdated(uint256 oldFee, uint256 newFee);
    event AssetSold(uint256 assetAmountIn, uint256 ebtcAmountOut, uint256 feeAmount);
    event AssetBought(uint256 ebtcAmountIn, uint256 assetAmountOut, uint256 feeAmount);

    function previewSellAsset(uint256 _assetAmountIn) external view returns (uint256 _ebtcAmountOut);
    function sellAsset(uint256 _assetAmountIn, address _recipient, uint256 _minOutAmount) external returns (uint256 _ebtcAmountOut);
    function sellAssetNoFee(uint256 _assetAmountIn, address _recipient, uint256 _minOutAmount) external returns (uint256 _ebtcAmountOut);
    function previewBuyAsset(uint256 _ebtcAmountIn) external view returns (uint256 _assetAmountOut);
    function buyAsset(uint256 _ebtcAmountIn, address _recipient, uint256 _minOutAmount) external returns (uint256 _assetAmountOut);
    function buyAssetNoFee(uint256 _ebtcAmountIn, address _recipient, uint256 _minOutAmount) external returns (uint256 _assetAmountOut);
    function totalMinted() external view returns (uint256);
}
