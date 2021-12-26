// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './libraries/Ownable.sol';
import './libraries/SafeERC20.sol';

interface IAlphaSparta {
    function mint(address account_, uint256 amount_) external;
}

interface IUniswapV2Router01 {
  function addLiquidity(
      address tokenA,
      address tokenB,
      uint amountADesired,
      uint amountBDesired,
      uint amountAMin,
      uint amountBMin,
      address to,
      uint deadline
  ) external returns (uint amountA, uint amountB, uint liquidity);
}

contract USDCSpartaPresale is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 amount; // Amount USDC deposited by user
        uint256 debt; // total SPARTA claimed by user
        bool claimed; // True if a user has claimed SPARTA
    }

    IERC20 public USDC;
    IERC20 public aSPARTA;
    IERC20 public SPARTA;
    IUniswapV2Router01 public router;

    uint decimalsUSDC = 6;
    uint decimalsSPARTA = 18;

    constructor(
        address _aSPARTA,
        address _SPARTA,
        address _USDC,
        address _router
    ) {
        aSPARTA = IERC20(_aSPARTA);
        SPARTA = IERC20(_SPARTA);
        USDC = IERC20(_USDC);
        router = IUniswapV2Router01(_router);
    }


    uint256 public price = 1 * 10**(decimalsUSDC - 2); // 0.01 USDC per SPARTA

    uint256 public lowTierCap = 500 * 10**decimalsUSDC; // 500 USDC cap per whitelisted user
    uint256 public highTierCap = 3000 * 10**decimalsUSDC; // 3000 USDC cap per whitelisted user

    uint256 public totalRaisedUSDC; // total USDC raised by sale

    uint256 public totalDebt; // total SPARTA owed to users

    bool public started; // true when sale is started

    bool public ended; // true when sale is ended

    bool public claimable; // true when sale is claimable

    bool public claimAlpha; // true when aSPARTA is claimable

    bool public contractPaused; // circuit breaker

    mapping(address => UserInfo) public userInfo;

    mapping(address => bool) public lowTierWhitelisted; // True if user is whitelisted
    mapping(address => bool) public highTierWhitelisted; // True if user is whitelisted

    mapping(address => uint256) public SPARTAClaimable; // amount of SPARTA claimable by address

    event Deposit(address indexed who, uint256 amount);
    event Withdraw(address token, address indexed who, uint256 amount);
    event SaleStarted(uint256 block);
    event SaleEnded(uint256 block);
    event ClaimUnlocked(uint256 block);
    event ClaimAlphaUnlocked(uint256 block);
    event AdminWithdrawal(address token);

    //* @notice modifer to check if contract is paused
    modifier checkIfPaused() {
        require(contractPaused == false, "contract is paused");
        _;
    }
    /**
     *  @notice adds a single whitelist to the sale
     *  @param _address: address to whitelist
     */
    function addLowTierWhitelist(address _address) external onlyOwner {
        require(!started, "Sale has already started");
        lowTierWhitelisted[_address] = true;
    }
    function addHighTierWhitelist(address _address) external onlyOwner {
        require(!started, "Sale has already started");
        highTierWhitelisted[_address] = true;
    }

    /**
     *  @notice adds multiple whitelist to the sale
     *  @param _addresses: dynamic array of addresses to whitelist
     */
    function addMultipleLowTierWhitelist(address[] calldata _addresses) external onlyOwner {
        require(!started, "Sale has already started");
        require(_addresses.length <= 333,"too many addresses");
        for (uint256 i = 0; i < _addresses.length; i++) {
            lowTierWhitelisted[_addresses[i]] = true;
        }
    }
    function addMultipleHighTierWhitelist(address[] calldata _addresses) external onlyOwner {
        require(!started, "Sale has already started");
        require(_addresses.length <= 333,"too many addresses");
        for (uint256 i = 0; i < _addresses.length; i++) {
            highTierWhitelisted[_addresses[i]] = true;
        }
    }

    /**
     *  @notice removes a single whitelist from the sale
     *  @param _address: address to remove from whitelist
     */
    function removeWhitelist(address _address) external onlyOwner {
        require(!started, "Sale has already started");
        lowTierWhitelisted[_address] = false;
        highTierWhitelisted[_address] = false;
    }

    // @notice Starts the sale
    function start() external onlyOwner {
        require(!started, "Sale has already started");
        started = true;
        emit SaleStarted(block.number);
    }

    // @notice Ends the sale
    function end() external onlyOwner {
        require(started, "Sale has not started");
        require(!ended, "Sale has already ended");
        ended = true;
        emit SaleEnded(block.number);
    }

    // @notice lets users claim SPARTA
    // @dev send sufficient SPARTA before calling
    function claimUnlock() external onlyOwner {
        require(ended, "Sale has not ended");
        require(!claimable, "Claim has already been unlocked");
        require(SPARTA.balanceOf(address(this)) >= totalDebt, 'not enough SPARTA in contract');
        claimable = true;
        emit ClaimUnlocked(block.number);
    }

    // @notice lets owner pause contract
    function togglePause() external onlyOwner returns (bool){
        contractPaused = !contractPaused;
        return contractPaused;
    }

    /**
     *  @notice it deposits USDC for the sale
     *  @param _amount: amount of USDC to deposit to sale
     */
    function deposit(uint256 _amount) external checkIfPaused {
        require(started, 'Sale has not started');
        require(!ended, 'Sale has ended');
        require(lowTierWhitelisted[msg.sender] == true || highTierWhitelisted[msg.sender] == true, 'msg.sender is not whitelisted user');

        UserInfo storage user = userInfo[msg.sender];

        if (highTierWhitelisted[msg.sender] == true) {
            require(highTierCap >= user.amount.add(_amount), 'new amount above user limit');
        }
        else if (lowTierWhitelisted[msg.sender] == true) {
            require(lowTierCap >= user.amount.add(_amount), 'new amount above user limit');
        }

        user.amount = user.amount.add(_amount);
        totalRaisedUSDC = totalRaisedUSDC.add(_amount);

        uint256 payout = _amount.mul(10**decimalsSPARTA).div(price); // aSPARTA to mint for _amount
        totalDebt = totalDebt.add(payout);

        USDC.safeTransferFrom(msg.sender, address(this), _amount);
            
        IAlphaSparta(address(aSPARTA)).mint(address(msg.sender), payout);

        emit Deposit(msg.sender, _amount);
    }

    /**
     *  @notice it deposits aSPARTA to withdraw SPARTA from the sale
     *  @param _amount: amount of aSPARTA to deposit to sale
     */
    function withdraw(uint256 _amount) external checkIfPaused {
        require(claimable, 'SPARTA is not yet claimable');
        require(_amount > 0, '_amount must be greater than zero');

        UserInfo storage user = userInfo[msg.sender];

        user.debt = user.debt.add(_amount);

        totalDebt = totalDebt.sub(_amount);

        aSPARTA.safeTransferFrom( msg.sender, address(this), _amount );

        SPARTA.safeTransfer( msg.sender, _amount );

        emit Withdraw(address(SPARTA), msg.sender, _amount);
    }

    // @notice it checks a users USDC allocation remaining
    function getUserRemainingAllocation(address _user) external view returns ( uint256 ) {
        require(lowTierWhitelisted[_user] == true || highTierWhitelisted[_user] == true, 'msg.sender is not whitelisted user');
        UserInfo memory user = userInfo[_user];
        
        if(highTierWhitelisted[_user] == true){
            return highTierCap.sub(user.amount);
        }
        return lowTierCap.sub(user.amount);
    }

    function addLiquidityAfterPresale(uint256 spartaTokenAmount) onlyOwner external {
        uint balanceUSDC = USDC.balanceOf(address(this));
        SPARTA.approve(address(router), spartaTokenAmount);
        USDC.approve(address(router), balanceUSDC);
        router.addLiquidity(address(SPARTA), address(USDC), spartaTokenAmount, balanceUSDC, 1, 1, address(router), block.number + 1);
    }
}