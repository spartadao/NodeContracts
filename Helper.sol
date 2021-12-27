// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './interface/IManager.sol';
import './interface/IERC20.sol';
import './utils/Ownable.sol';

interface IPool {
    function pay(address _to, uint _amount) external returns (bool);
}

contract Helper is Ownable {
    IManager public manager;
    IERC20 public token;

    address public team;
    address public dao;
    IPool public pool;

    uint public teamFee;
    uint public daoFee;

    constructor(address _manager, address _token, address _pool, address _dao, address teamAdrs, uint _teamFee, uint _daoFee) {
        manager = IManager(_manager);
        token = IERC20(_token);
        pool = IPool(_pool);
        dao = _dao;
        team = teamAdrs;
        teamFee = _teamFee;
        daoFee = _daoFee;
    }

    function setDefaultFees(uint256[] memory fees) public onlyOwner {
        teamFee = fees[0];
        daoFee = fees[1];
    }

    function updateTeamAddress(address payable _team) external onlyOwner {
        team = _team;
    }

    function updatePoolAddress(address _pool) external onlyOwner {
        pool.pay(address(owner()), token.balanceOf(address(pool)));
        pool = IPool(_pool);
    }

    function updateLiquiditFee(uint256 _fee) external onlyOwner {
        daoFee = _fee;
    }

    function updateTeamFee(uint256 _fee) external onlyOwner {
        teamFee = _fee;
    }

    function _transferIt(uint contractTokenBalance) internal {
        uint256 teamTokens = (contractTokenBalance * teamFee) / 100;
        token.transfer(team, teamTokens);

        uint256 daoTokens = (contractTokenBalance * daoFee) / 100;
        token.transfer(dao, daoTokens);
    }

    function createNodeWithTokens(string memory name) public {
        require(bytes(name).length > 0 && bytes(name).length < 33, "HELPER: name size is invalid");
        address sender = _msgSender();
        require(sender != address(0), "HELPER:  Creation from the zero address");
        require(sender != team, "HELPER: Team cannot create node");
        uint256 nodePrice = manager.price();
        require(token.balanceOf(sender) >= nodePrice, "HELPER: Balance too low for creation.");
        token.transferFrom(_msgSender(), address(this), nodePrice);
        uint256 contractTokenBalance = token.balanceOf(address(this));
        _transferIt(contractTokenBalance);
        manager.createNode(sender, name);
    }

    function createMultipleNodeWithTokens(string memory name, uint amount) public {
        require(bytes(name).length > 0 && bytes(name).length < 33, "HELPER: name size is invalid");
        address sender = _msgSender();
        require(sender != address(0), "HELPER:  Creation from the zero address");
        require(sender != team, "HELPER: Team cannot create node");
        uint256 nodePrice = manager.price();
        uint256 totalCost = nodePrice * amount;
        require(token.balanceOf(sender) >= totalCost, "HELPER: Balance too low for creation.");
        token.transferFrom(_msgSender(), address(this), totalCost);
        uint256 contractTokenBalance = token.balanceOf(address(this));
        _transferIt(contractTokenBalance);
        for (uint256 i = 0; i < amount; i++) {
            manager.createNode(sender, name);   
        }
    }

    function createMultipleNodeWithTokensAndName(string[] memory names, uint amount) public {
        require(names.length == amount, "HELPER: You need to provide exactly matching names");
        address sender = _msgSender();
        require(sender != address(0), "HELPER:  creation from the zero address");
        require(sender != team, "HELPER: Team cannot create node");
        uint256 nodePrice = manager.price();
        uint256 totalCost = nodePrice * amount;
        require(token.balanceOf(sender) >= totalCost, "HELPER: Balance too low for creation.");
        token.transferFrom(_msgSender(), address(this), totalCost);
        uint256 contractTokenBalance = token.balanceOf(address(this));
        _transferIt(contractTokenBalance);
        for (uint256 i = 0; i < amount; i++) {
            string memory name = names[i];
            require(bytes(name).length > 0 && bytes(name).length < 33, "HELPER: name size is invalid");
            manager.createNode(sender, name); 
        }
    }

    function claimAll(address account) public returns (bool) {
        address sender = _msgSender();
        require(account == sender, "HELPER: you can't claim others rewards");

        uint256 rewardAmount = manager.claimAll(account);

        require(rewardAmount > 0,"HELPER: You don't have enough reward to cash out");
        return pool.pay(sender, rewardAmount);
    }

    function claim(uint256 _node) public returns (bool) {
        address sender = _msgSender();
        require(sender != address(0), "HELPER: creation from the zero address");
        require(sender != team, "HELPER: team cannot cashout rewards");
        uint256 rewardAmount = manager.claim(_msgSender(), _node);
        require(rewardAmount > 0,"HELPER: You don't have enough reward to cash out");
        return pool.pay(sender, rewardAmount);
    }
}