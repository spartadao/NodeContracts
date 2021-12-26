// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './Context.sol';

contract MinterOwnable is Context {
    address internal _minterContract;

    event MinterOwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Returns the address of the current owner.
     */
    function minterContract() public view returns (address) {
        return _minterContract;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyMinter() {
        require(_minterContract == _msgSender(), "Ownable: caller is not the Minter");
        _;
    }
}