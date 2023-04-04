pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "./interfaces/ERC20Interface.sol";

contract Defi321 {

    address public owner;
    address public rewardToken;
    uint feeRate = 2;
    // It means one thouthousand US dollers
    uint FeePoolLimit = 1000;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only contract owner can call this function");
        _;
    }

    constructor(address _rewardToken) public {
        owner = msg.sender;
        rewardToken = _rewardToken;
    }

    struct Receipt {
        address sender;
        address tokenA;
        address tokenB;
        uint tokenAAmount;
        uint tokenBAmount;
    }

    mapping(bytes32 => Receipt[]) pairReceipt;

    mapping(address => uint) rewards;

    struct Pool {
        bytes32 id;
        address tokenA;
        address tokenB;
        uint totalA;
        uint totalB;
        uint currentFee;
    }

    mapping(bytes32 => Pool) pools;

    function swap(address _fromTokenAddress, address _toTokenAddress, uint _amount) public payable {
        ERC20Interface _fromToken = ERC20Interface(_fromTokenAddress);
        require(_fromToken.allowance(msg.sender, address(this)) >= _amount, "Token allowance not set for exchange");
        ERC20Interface _toToken = ERC20Interface(_toTokenAddress);

        uint256 _fromTokenBalance = _fromToken.balanceOf(msg.sender);
        require(_amount <= _fromTokenBalance, "Insufficient balance.");
        uint256 _toTokenBalance = _toToken.balanceOf(address(this));

        uint _currentFromTokenPrice = getPrice();
        uint _currentToTokenPrice = getPrice();
        uint _targetAmount = _currentFromTokenPrice / _currentToTokenPrice * _amount;

        uint _resultAmount = _targetAmount * (100 - feeRate) / 100;
        require(_resultAmount <= _toTokenBalance, "Insufficient liquidity.");

        _fromToken.transferFrom(msg.sender, address(this), _amount);
        _toToken.transfer(msg.sender, _resultAmount);

        bytes32 pairId = getPairId(_fromTokenAddress, _toTokenAddress);
        Pool storage pool = pools[pairId];
        pool.currentFee = pool.currentFee + _currentToTokenPrice * _amount * feeRate / 100;

        if (pool.currentFee >= FeePoolLimit) {
            calculateReward(pairId);
        }
    }

    function provideLiquidity(address _tokenAAddress, address _tokenBAddress, uint _amountA, uint _amountB) public payable {
        ERC20Interface _tokenA = ERC20Interface(_tokenAAddress);
        ERC20Interface _tokenB = ERC20Interface(_tokenBAddress);

        uint256 _tokenABalance = _tokenA.balanceOf(msg.sender);
        uint256 _tokenBBalance = _tokenB.balanceOf(msg.sender);
        require(_amountA <= _tokenABalance, "Insufficient balance.");
        require(_tokenA.allowance(msg.sender, address(this)) >= _amountA, "Token allowance not set for exchange");
        require(_amountB <= _tokenBBalance, "Insufficient balance.");
        require(_tokenB.allowance(msg.sender, address(this)) >= _amountB, "Token allowance not set for exchange");

        _tokenA.transferFrom(msg.sender, address(this), _amountA);
        _tokenB.transferFrom(msg.sender, address(this), _amountB);

        bytes32 pairId = getPairId(_tokenAAddress, _tokenBAddress);

        if (existOwnReceipt(pairId)) {
            uint index = getOwnReceiptIndex(pairId);
            Receipt storage receipt = pairReceipt[pairId][index];
            receipt.tokenAAmount = receipt.tokenAAmount  + _amountA;
            receipt.tokenBAmount = receipt.tokenBAmount  + _amountB;
        } else {
            pairReceipt[pairId].push(Receipt(
                msg.sender,
                _tokenAAddress,
                _tokenBAddress,
                _amountA,
                _amountB
            ));
        }

        Pool storage pool = pools[pairId];
        pool.totalA = pool.totalA + _amountA;
        pool.totalB = pool.totalB + _amountB;
    }

    function getPairId(address _tokenA, address _tokenB) public pure returns (bytes32) {
        if (_tokenA > _tokenB) {
            // INFO: これはいらない？
            return keccak256(abi.encodePacked(_tokenA, _tokenB));
        } else {
            return keccak256(abi.encodePacked(_tokenB, _tokenA));
        }
    }

    function withdrawLiquidity(address _tokenAAddress, address _tokenBAddress, uint _amountA, uint _amountB) public payable {
        ERC20Interface _tokenA = ERC20Interface(_tokenAAddress);
        ERC20Interface _tokenB = ERC20Interface(_tokenBAddress);

        uint256 _tokenABalance = _tokenA.balanceOf(address(this));
        uint256 _tokenBBalance = _tokenB.balanceOf(address(this));
        require(_amountA <= _tokenABalance, "Insufficient liquidity.");
        require(_amountB <= _tokenBBalance, "Insufficient liquidity.");
        bytes32 pairId = getPairId(_tokenAAddress, _tokenBAddress);

        uint index = getOwnReceiptIndex(pairId);
        Receipt storage receipt = pairReceipt[pairId][index];
        receipt.tokenAAmount = receipt.tokenAAmount  + _amountA;
        receipt.tokenBAmount = receipt.tokenBAmount  + _amountB;

        require(receipt.tokenAAmount >= _amountA, "amount is wrong");
        require(receipt.tokenBAmount >= _amountB, "amount is wrong");

        _tokenA.transfer(msg.sender, _amountA);
        _tokenB.transfer(msg.sender, _amountB);

        receipt.tokenAAmount = receipt.tokenAAmount - _amountA;
        receipt.tokenBAmount = receipt.tokenBAmount - _amountB;

        Pool storage pool = pools[pairId];
        pool.totalA = pool.totalA - _amountA;
        pool.totalB = pool.totalB - _amountB;
    }

    function claim() public {
        uint amount = rewards[msg.sender];
        uint _ethPrice = getPrice();
        uint rewardAmount = amount / _ethPrice;
        ERC20Interface _token = ERC20Interface(rewardToken);
        _token.transfer(msg.sender, rewardAmount);
        rewards[msg.sender] = 0;
    }

    function calculateReward(bytes32 pairId) public {

        Receipt[] storage pair = pairReceipt[pairId];
        uint pairLength = pair.length;
        Pool storage pool = pools[pairId];

        for (uint i = 0; i < pairLength; i++) {

            address sender = pair[i].sender;
            uint priceA = getPrice();
            uint balanceA = priceA * pair[i].tokenAAmount;

            uint priceB = getPrice();
            uint balanceB = priceB * pair[i].tokenBAmount;
            uint balance = balanceA + balanceB;

            uint poolBalanceA = priceA * pool.totalA;
            uint poolBalanceB = priceB * pool.totalB;
            uint poolBalance = poolBalanceA + poolBalanceB;

            uint rate = balance / poolBalance;
            uint rewardAmount = rate * pool.currentFee;

            uint amount = rewards[sender];
            rewards[sender] = amount + rewardAmount;
        }

        pool.currentFee = 0;
    }

    function getPrice() public view returns (uint256) {
        return 1000;
    }

    function createPool(address _addressA, address _addressB) external onlyOwner {
        bytes32 pairId = getPairId(_addressA, _addressB);

        if (pools[pairId].id != 0) {
            revert("duplicate pool");
        }

        Pool memory newPool = Pool({
            id: pairId,
            tokenA: _addressA,
            tokenB: _addressB,
            totalA: 0,
            totalB: 0,
            currentFee: 0
        });
        pools[pairId] = newPool;
    }

    function existOwnReceipt(bytes32 pairId) public view returns (bool) {
        for (uint i = 0; i < pairReceipt[pairId].length; i++) {
            if (pairReceipt[pairId][i].sender == msg.sender) {
                return true;
            }
        }
        return false;
    }

    function getOwnReceiptIndex(bytes32 pairId) public view returns (uint) {
        for (uint i = 0; i < pairReceipt[pairId].length; i++) {
            if (pairReceipt[pairId][i].sender == msg.sender) {
                return i;
            }
        }
        revert("Receipt not found.");
    }

    function getCurrentReward() public view returns (uint) {
        return rewards[msg.sender];
    }

    function getPool(bytes32 pairId) public view returns (Pool memory) {
        return pools[pairId];
    }
}