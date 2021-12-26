// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './utils/ERC20.sol';
import './utils/Ownable.sol';
import './utils/MinterOwnable.sol';

contract Soldier is ERC20, Ownable, MinterOwnable {
    mapping(address => bool) public _isBlacklisted;

    constructor(
        address presale

    ) ERC20("Sparta", "SPARTA") {
        _minterContract = presale;
    }

    function blacklistMalicious(address account, bool value) external onlyOwner {
        _isBlacklisted[account] = value;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {       
        _transfer(msg.sender, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(!_isBlacklisted[from] && !_isBlacklisted[to],"Blacklisted address");
        super._transfer(from, to, amount);
    }

    function mint(address account, uint256 amount) external onlyMinter {
        require(account != address(0), "ERC20: mint to the zero address");
        _mint(account, amount);
    }

    function transferMinterOwnership(address newMinter) external onlyOwner {
        emit MinterOwnershipTransferred(minterContract(), newMinter);
        _minterContract = newMinter;
    }
}