// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './IERC721.sol';

interface IArmyManager is IERC721 {
    function price() external returns(uint256);
    function createNode(address account, string memory nodeName) external;
    function claim(address account, uint256 _id) external returns (uint);
    function claimAll(address account) external returns (uint);
    function importArmy(address account, string calldata _name, uint64 mint, uint64 _claim) external; 
    function getNameOf(uint256 _id) external view returns (string memory);
    function getMintOf(uint256 _id) external view returns (uint64);
    function getClaimOf(uint256 _id) external view returns (uint256);
    function getPrice() external view returns(uint256);
}