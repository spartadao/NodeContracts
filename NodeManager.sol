// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './utils/Ownable.sol';
import './utils/HelperOwnable.sol';
import './utils/WeigthOwnable.sol';
import './interface/IERC721Metadata.sol';
import './interface/IERC721Receiver.sol';
import './interface/IManager.sol';
import './library/Address.sol';


contract Manager is Ownable, HelperOwnable, WeigthOwnable, IERC721, IERC721Metadata, IManager {
    using Address for address;

    struct Army {
        string name;
        string metadata;
        uint256 id;
        uint64 mint;
        uint256 claim;
        uint64 weigth;
    }

    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _owners;
    mapping(uint256 => Army) private _nodes;
    mapping(address => uint256[]) private _bags;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    mapping(address => bool) private _blacklist;

    uint256 public override price;
    // uint32 public precision = 100000000;
    uint32 public precision = 10**9;
    uint256 public reward;
    // uint128 public claimTime = 1; in seconds
    uint128 public claimTime = 3600;
    // uint128 public claimTime = 86400;
    string public defaultUri;

    uint256 private nodeCounter = 1;

    constructor (uint256 _price, uint256 _reward, string memory _defaultUri){
        price = _price;
        reward = _reward;
        defaultUri = _defaultUri;
    }

    function name() external override pure returns (string memory) {
        return "Sparta Platoon";
    }

    function symbol() external override pure returns (string memory) {
        return "PLATOON";
    }

    modifier onlyIfExists(uint256 _id) {
        require(_exists(_id), "ERC721: operator query for nonexistent token");
        _;
    }

    function totalNodesCreated() view external returns (uint) {
        return nodeCounter - 1;
    }

    function isBlacklisted(address wallet) view external returns (bool) {
        return _blacklist[wallet];
    }

    function importArmy(address account, string memory _name, uint64 mint, uint64 _claim) onlyHelper override external {
        uint256 nodeId = nodeCounter;
        _createArmy(nodeId, _name, mint, _claim, "", account, 1);
        nodeCounter += 1;
    }

    function createNode(address account, string memory nodeName) onlyHelper override external {
        uint256 nodeId = nodeCounter;
        _createArmy(nodeId, nodeName, uint64(block.timestamp), uint64(block.timestamp), "", account, 1);
        nodeCounter += 1;
    }

    function claim(address account, uint256 _id) external onlyIfExists(_id) onlyHelper override returns (uint) {
        require(ownerOf(_id) == account, "MANAGER: You are not the owner");
        Army storage _node = _nodes[_id];

        uint percentTimeElapsed = (block.timestamp - _node.claim) * precision / claimTime;
        uint rewardNode = reward * percentTimeElapsed / precision;

        if(rewardNode > 0) {
            _node.claim = uint256(block.timestamp);
            return rewardNode;
        } else {
            return 0;
        }
    }
    
    function claimInternal(uint256 _id) internal returns (uint256) {
        Army storage _node = _nodes[_id];

        uint256 percentTimeElapsed = (block.timestamp - _node.claim) * precision / claimTime;
        uint256 rewardNode = reward * percentTimeElapsed / precision;

        _node.claim = uint256(block.timestamp);
        return rewardNode;
    }

    function claimAll(address account) external onlyHelper override returns (uint256) {
        uint256 rewards = 0;
        for (uint256 i = 0; i < _bags[account].length; i++) {
            rewards += claimInternal(_bags[account][i]);
        }
        return rewards;
    }

    function getAllPendingRewards(address account) public view returns (uint) {
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < _bags[account].length; i++) {
            uint256 nodeId = _bags[account][i];
            Army memory node = _nodes[nodeId];
            uint percentTimeElapsed = (block.timestamp - node.claim) * precision / claimTime;
            uint rewardNode = reward * percentTimeElapsed / precision;
            totalRewards += rewardNode;
        }
        return totalRewards;
    }

    function getNodesAccount(address account) public view returns (uint256 [] memory){
        return _bags[account];
    }
    function getNodesCountAccount(address account) public view returns (uint256){
        return _bags[account].length;
    }

    function updateArmy(uint256 id, uint64 weigth, string calldata metadata) onlyWeigth external {
        Army storage army = _nodes[id];
        army.weigth = weigth;
        army.metadata = metadata;
    }

    function getArmy(uint256 _id) public view onlyIfExists(_id) returns (Army memory) {
        return _nodes[_id];
    }

    function getRewardOf(uint256 _id) public view onlyIfExists(_id) returns (uint) {
        Army memory node = _nodes[_id];
        uint percentTimeElapsed = (block.timestamp - node.claim) * precision / claimTime;
        return reward * percentTimeElapsed / precision;
    }

    function getNameOf(uint256 _id) public view override onlyIfExists(_id) returns (string memory) {
        return _nodes[_id].name;
    }

    function getMintOf(uint256 _id) public view override onlyIfExists(_id) returns (uint64) {
        return _nodes[_id].mint;
    }

    function getClaimOf(uint256 _id) public view override onlyIfExists(_id) returns (uint256) {
        return _nodes[_id].claim;
    }

    function getArmiesOf(address _account) public view returns (uint256[] memory) {
        return _bags[_account];
    }

    function getWeightOf(uint256 _id) public view onlyIfExists(_id) returns (uint64) {
        return _nodes[_id].weigth;
    }

    function getPrice() external view override returns (uint256) {
        return price;
    }

    function _changeArmyPrice(uint256 newPrice) onlyOwner external {
        price = newPrice;
    }

    function _changeRewardPerArmy(uint64 newReward) onlyOwner external {
        reward = newReward;
    }

    function _changeClaimTime(uint64 newTime) onlyOwner external {
        claimTime = newTime;
    }

    function _changeRewards(uint64 newReward, uint64 newTime, uint32 newPrecision) onlyOwner external {
        reward = newReward;
        claimTime = newTime;
        precision = newPrecision;
    }

    function _setTokenUriFor(uint256 nodeId, string memory uri) onlyOwner external {
        _nodes[nodeId].metadata = uri;
    }

    function _setDefaultTokenUri(string memory uri) onlyOwner external {
        defaultUri = uri;
    }

    function _setBlacklist(address malicious, bool value) onlyOwner external {
        _blacklist[malicious] = value;
    }

    function _addArmy(uint256 _id, string calldata _name, uint64 _mint, uint64 _claim, string calldata _metadata, address _to, uint64 _weigth) onlyOwner external {
        _createArmy(_id, _name, _mint, _claim, _metadata, _to, _weigth);
    }

    function _deleteArmy(uint256 _id) onlyOwner external {
        address owner = ownerOf(_id);
        _balances[owner] -= 1;
        delete _owners[_id];
        delete _nodes[_id];
        _remove(_id, owner); 
    }

    function _deleteMultipleArmy(uint256[] calldata _ids) onlyOwner external {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            address owner = ownerOf(_id);
            _balances[owner] -= 1;
            delete _owners[_id];
            delete _nodes[_id];
            _remove(_id, owner);
        }
    }


    function transferWeigthOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit WeigthOwnershipTransferred(_weigthContract, newOwner);
        _weigthContract = newOwner;
    }

    function _createArmy(uint256 _id, string memory _name, uint64 _mint, uint64 _claim, string memory _metadata, address _to, uint64 _weigth) internal {
        require(!_exists(_id), "MANAGER: Army already exist");
        _nodes[_id] = Army({
            name: _name,
            mint: _mint,
            claim: _claim,
            id: _id,
            metadata: _metadata,
            weigth: _weigth
        });
        _owners[_id] = _to;
        _balances[_to] += 1;
        _bags[_to].push(_id);

        emit Transfer(address(0), _to, _id);
    }

    function _remove(uint256 _id, address _account) internal {
        uint256[] storage _ownerNodes = _bags[_account];
        uint length = _ownerNodes.length;

        uint _index = length;
        
        for (uint256 i = 0; i < length; i++) {
            if(_ownerNodes[i] == _id) {
                _index = i;
            }
        }
        if (_index >= _ownerNodes.length) return;
        
        _ownerNodes[_index] = _ownerNodes[length - 1];
        _ownerNodes.pop();
    }

    function tokenURI(uint256 tokenId) external override view returns (string memory) {
        Army memory _node = _nodes[uint64(tokenId)];
        if(bytes(_node.metadata).length == 0) {
            return defaultUri;
        } else {
            return _node.metadata;
        }
    }

    function balanceOf(address owner) public override view returns (uint256 balance){
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public override view onlyIfExists(uint64(tokenId)) returns (address owner) {
        address theOwner = _owners[uint64(tokenId)];
        return theOwner;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId ) external override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function renameArmy(uint64 id, string memory newName) external {
        require(ownerOf(id) == msg.sender, "MANAGER: You are not the owner");
        Army storage army = _nodes[id];
        army.name = newName;
    }

    function transferFrom(address from, address to,uint256 tokenId) external override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function approve(address to, uint256 tokenId) external override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint256 tokenId) public override view onlyIfExists(uint64(tokenId)) returns (address operator){
        return _tokenApprovals[uint64(tokenId)];
    }

    function setApprovalForAll(address operator, bool _approved) external override {
        _setApprovalForAll(_msgSender(), operator, _approved);
    }

    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    function supportsInterface(bytes4 interfaceId) external override pure returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal {
        uint64 _id = uint64(tokenId);
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");
        require(!_blacklist[to], "MANAGER: You can't transfer to blacklisted user");
        require(!_blacklist[from], "MANAGER: You can't transfer as blacklisted user");

        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[_id] = to;

        _bags[to].push(_id);
        _remove(_id, from);

        emit Transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[uint64(tokenId)] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view onlyIfExists(uint64(tokenId)) returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[uint64(tokenId)] != address(0);
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);
        _approve(address(0), tokenId);
        _balances[owner] -= 1;
        delete _owners[uint64(tokenId)];
        delete _nodes[uint64(tokenId)];
        _remove(uint64(tokenId), owner);
        emit Transfer(owner, address(0), tokenId);
    }

    function transferHelperOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit HelperOwnershipTransferred(_helperContract, newOwner);
        _helperContract = newOwner;
    }
}