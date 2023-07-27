// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Router01 {
    function fnFactory() external pure returns (address);
    function fnWETH() external pure returns (address);

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
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


contract Staking is AccessControl {

    bytes32 constant public ADMIN_ROLE = keccak256("Admin Role");

    struct User {
        uint256 stakeTime;
        uint256 lastClaimTime;
        uint256 packageIndex;
        uint256 amount;
        uint256 tokenId;
        bool isActive;
        uint256 fxoAmount;
    }
    mapping(address => User[]) public users;

    mapping(address => uint256) public guaranteeTokenAmounts;

    address public treasuryAddress = 0xb2C6B986e3E7Eab736E4FcF5e380F3a5CFa56340;
    bool public enableTreasury = true;
    bool public enableBuyFxo = false;


    uint256[4] public defaultPackages = [1000 ether, 2000 ether, 5000 ether,300 ether];
    uint256[4] public defaultPkgAPY = [25, 28, 31, 25];
    uint256[4] public defaultPkgTimePeriod = [365 days, 548 days ,2*365 days, 2*365 days];
    bool[4] public defaultPkgStakable = [true, true,true, true];

    uint256 public penaltyPercent = 10;
    uint256 public minAmountToGetReward = 10 ether;
    uint256 public minAmountToStakeWithFxo = 10 ether;
    uint256 public minAmountToBuyFxo = 10 ether;
    bool public enableMinAmountToGetReward = false;
    uint256 public liveTimePeriod = 1 seconds;

    bool public lastPackageEnabled = true;

    IUniswapV2Router02 public uniswapV2Router;

    IERC20 public tokenUSDT;
    IERC20 public tokenFXO;
    IERC20 public tokenFXOne;
   
    modifier onlyAdmin {
        require(hasRole(ADMIN_ROLE, msg.sender), "!admin");
        _;
    }

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, treasuryAddress);
        uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        tokenUSDT  = IERC20(0x55d398326f99059fF775485246999027B3197955);
        tokenFXO   = IERC20(0x5B281084063d77254342921c846e3E621883CF8F);
        tokenFXOne = IERC20(0xa614b052676d5846D62A562bD6Db4dEEd0Fa204c);

    }

    modifier stakingStarted {
        uint256 guaranteeBalance = tokenFXOne.balanceOf(address(this));
        uint256 rewardBalance = tokenFXO.balanceOf(address(this));
        require(guaranteeBalance > 0 && rewardBalance > 0, "!Not Start");
        _;
    }

    function stake(uint256 amount, address _address, uint256 tokenId) public stakingStarted {
        IERC20 token;
        uint256 investedFxoAmount = 0;
        if (tokenId == 0) {
            token = tokenUSDT;
        }
        if (tokenId == 1) {
            uint256 userAmount = 0;
            for (uint256 i = 0; i < users[_address].length; i++) {
                userAmount += users[_address][i].amount;
            }
            require(userAmount >= minAmountToStakeWithFxo, "Insufficient Stake Amount");
            investedFxoAmount = getRewardByUSDT(amount);
            token = tokenFXO;
        }


        bool packageExist = false;
        uint256 packageIndex;
        for (uint256 i = 0; i < defaultPackages.length; i++) {
            if (amount == defaultPackages[i] && defaultPkgStakable[i]==true)  
            {
                packageExist = true;
                packageIndex = i;
            }
        }

        require(packageExist, "Invalid Package");
        if (enableTreasury) {
            token.transferFrom(msg.sender, treasuryAddress, tokenId == 1 ? investedFxoAmount : amount);
        } else {
            token.transferFrom(msg.sender, address(this), tokenId == 1 ? investedFxoAmount : amount);
        }
        tokenFXOne.transfer(_address, amount);
        guaranteeTokenAmounts[_address] += amount;
        users[_address].push(User({
            stakeTime: block.timestamp,
            lastClaimTime: block.timestamp,
            packageIndex: packageIndex,
            amount: amount,
            tokenId: tokenId,
            isActive: true,
            fxoAmount: investedFxoAmount
        }));

    }

    function updateStaking(
        uint256 stakeTime,
        uint256 lastClaimTime,
        address user
    ) public onlyAdmin {
        bool stakeExist;
        uint256 stakeIndex;
        for (uint256 i = 0; i < users[user].length; i++) {
            if (stakeTime == users[user][i].stakeTime) {
                stakeExist = true;
                stakeIndex = i;
            }
        }
        require(stakeExist, "Invalid Stake Time");
        require(users[user][stakeIndex].isActive, "Already Unstaked");
        users[user][stakeIndex].stakeTime = stakeTime;
        users[user][stakeIndex].lastClaimTime = lastClaimTime;
    }

    function buyFxo(uint256 amount) public {
        require(enableBuyFxo, "Buy Is Not Active");
        uint256 userAmount = 0;
        for (uint256 i = 0; i < users[msg.sender].length; i++) {
            userAmount += users[msg.sender][i].amount;
        }
        require(userAmount >= minAmountToBuyFxo, "Insufficient Stake Amount");
        if (enableTreasury) {
            tokenUSDT.transferFrom(msg.sender, treasuryAddress, amount);
        } else {
            tokenUSDT.transferFrom(msg.sender, address(this), amount);
        }
        uint256 fxoAmount = getRewardByUSDT(amount);
        tokenFXO.transfer(msg.sender, fxoAmount);
    }

    function unStake(uint256 stakeTime, address user, bool urgentUnstake) public onlyAdmin {
        require(users[user].length > 0, "!NO Stake");
        uint256 reward = earned(user);
        if (enableMinAmountToGetReward) {
            require(reward >= minAmountToGetReward || urgentUnstake, "!Insufficient Reward");
        }

        require(reward > 0 || urgentUnstake, "!Unavailable");

        bool stakeExist;
        uint256 stakeIndex;
        for (uint256 i = 0; i < users[user].length; i++) {
            if (stakeTime == users[user][i].stakeTime) {
                stakeExist = true;
                stakeIndex = i;
            }
        }
        require(stakeExist, "Invalid Stake Time");
        require(users[user][stakeIndex].isActive, "Already Unstaked");
        uint256 allowance = tokenFXOne.allowance(msg.sender, address(this));
        require(allowance >= users[user][stakeIndex].amount, "FXOne Allowance");
        tokenFXOne.transferFrom(user, address(this), users[user][stakeIndex].amount);

        uint256 rewardTokenAmount = getRewardByUSDT(reward);
        tokenFXO.transfer(user, rewardTokenAmount);

        IERC20 token;
        if (users[user][stakeIndex].tokenId == 0) { token = tokenUSDT; }
        if (users[user][stakeIndex].tokenId == 1) { token = tokenFXO; }


        token.transfer(user, users[user][stakeIndex].tokenId == 1 ? (users[user][stakeIndex].fxoAmount * (100 - penaltyPercent)) / 100 : (users[user][stakeIndex].amount * (100 - penaltyPercent)) / 100);
        users[user][stakeIndex].lastClaimTime = block.timestamp;
        users[user][stakeIndex].isActive = false;
        guaranteeTokenAmounts[user] -= users[user][stakeIndex].amount;
    }

    function earned(address user) public view returns(uint256 reward) {
        reward = 0;
        for (uint i = 0; i < users[user].length; i++) {
            if (users[user][i].isActive) {
                uint256 periodByDay = (block.timestamp - users[user][i].lastClaimTime) / defaultPkgTimePeriod[users[user][i].packageIndex];
                reward += periodByDay * users[user][i].amount * defaultPkgAPY[users[user][i].packageIndex] / 365 / 100;
            }
        }
    }

    function earnedLive(address user) public view returns(uint256 reward) {
        reward = 0;
        for (uint i = 0; i < users[user].length; i++) {
            if (users[user][i].isActive) {
                uint256 periodByDay = (block.timestamp - users[user][i].lastClaimTime) / liveTimePeriod;
                reward += periodByDay * users[user][i].amount * defaultPkgAPY[users[user][i].packageIndex] / 365 / 100;
            }
        }
    }

    function withdrawReward(address user) public onlyAdmin {
        uint256 reward = earned(user);
        require(reward >= minAmountToGetReward, "!Insufficient Reward");

        uint256 rewardTokenAmount = getRewardByUSDT(reward);
        tokenFXO.transfer(user, rewardTokenAmount);
        for (uint i = 0; i < users[user].length; i++) {
             if (users[user][i].isActive) {
                users[user][i].lastClaimTime = block.timestamp;
             }
        }
    }

    function getRewardByUSDT(uint256 rewardAmount) public view returns(uint256) {
        address[] memory path = new address[](2);
        path[0] = address(tokenUSDT);
        path[1] = address(tokenFXO);
        return uniswapV2Router.getAmountsOut(rewardAmount, path)[1];
    }

    function setUSDT(IERC20 newUSDT) public onlyAdmin {
        tokenUSDT = newUSDT;
    }

    function setGuaranteeToken(IERC20 newGuaranteeToken) public onlyAdmin {
        tokenFXOne = newGuaranteeToken;
    }


    function setRewardToken(IERC20 newRewardToken) public onlyAdmin {
        tokenFXO = newRewardToken;
    }

    function setMinAmountToGetReward(uint256 newAmount) public onlyAdmin {
        minAmountToGetReward = newAmount;
    }

    function updateEnableTreasury(bool _enable) public onlyAdmin {
        enableTreasury = _enable;
    }

    function updateEnableBuyFxo(bool _enable) public onlyAdmin {
        enableBuyFxo = _enable;
    }

    function setTreasuryAddress(address _treasuryAddress) public onlyAdmin {
        treasuryAddress = _treasuryAddress;
    }

    function setMinAmountToBuyFxo (uint256 newAmount) public onlyAdmin {
        minAmountToBuyFxo = newAmount;
    }

    function setLiveTimePeriod(uint256 _liveTimePeriod) public onlyAdmin {
        liveTimePeriod = _liveTimePeriod;
    }

    function setDefaultPackages(uint256[4] memory newDefaultPackages) public onlyAdmin {
        defaultPackages = newDefaultPackages;
    }

    function setDefaultPkgAPY(uint256[4] memory newDefaultPkgAPY) public onlyAdmin {
        defaultPkgAPY = newDefaultPkgAPY;
    }
    
    function setDefaultPkgTimePeriod(uint256[4] memory newPkgTimePeriod) public onlyAdmin {
        defaultPkgTimePeriod = newPkgTimePeriod;
    }

    function setDefaultPkgStakable(bool[4] memory newPkgStakable) public onlyAdmin {
        defaultPkgStakable = newPkgStakable;
    }

    function setLastPackageEnabled(bool _lastPackageEnabled) public onlyAdmin {
        lastPackageEnabled = _lastPackageEnabled;
    }

    function setPenaltyPercent(uint256 percent) public onlyAdmin {
        penaltyPercent = percent;
    }

    function setMinAmountToStakeWithFxo(uint256 _minAmountToStakeWithFxo) public onlyAdmin {
        minAmountToStakeWithFxo = _minAmountToStakeWithFxo;
    }

    function setEnableMinAmountToGetReward(bool _enableMinAmountToGetReward) public onlyAdmin {
        enableMinAmountToGetReward = _enableMinAmountToGetReward;
    }

    function adminWithdrawTokens(uint256 amount, address _to, address _tokenAddr) public onlyAdmin {
        require(_to != address(0));
        if(_tokenAddr == address(0)){
            payable(_to).transfer(amount);
        }else{
            IERC20(_tokenAddr).transfer(_to, amount);
        }
    }

    function getUserInfo(address user) public view returns(
        User[30] memory info
    ){
        for(uint256 i = 0; i < users[user].length; i++){
            info[i] = users[user][i];
        }
    }

}