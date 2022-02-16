// SPDX-License-Identifier: MIT
/*
* ███    ███  ██████   ██████  ███    ██ ███████ ██      ██ ██████  
* ████  ████ ██    ██ ██    ██ ████   ██ ██      ██      ██ ██   ██ 
* ██ ████ ██ ██    ██ ██    ██ ██ ██  ██ █████   ██      ██ ██████  
* ██  ██  ██ ██    ██ ██    ██ ██  ██ ██ ██      ██      ██ ██      
* ██      ██  ██████   ██████  ██   ████ ██      ███████ ██ ██      
*
* Website: https://www.moonflip.net/
* Twitter: https://twitter.com/moonflipcrypto
* Discord: https://discord.gg/etyvUAMat7
* Telegram: https://t.me/moonfliptoken
*/

import './misc/ERC20.sol';
import './misc/Ownable.sol';
import './interfaces/IRewards.sol';
import './interfaces/IERC20.sol';
import './interfaces/IRouter.sol';
import './interfaces/IUniswapV2Pair.sol';
import './library/SafeMath.sol';
import './library/Address.sol';


pragma solidity >=0.6.12;

contract Token is Context, IERC20, ERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;
    
    IRewards reward;

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) public _isBlacklisted;

    mapping (address => bool) private _isExcludedFromFee;
    mapping (address => bool) private _isExcluded;

    address[] private _excluded;
   
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _maxSupply = 10000000000 * 10**18;
    uint256 private _tTotal = _maxSupply;   
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    uint256 private _tBurnTotal;
    
    string private _name;
    string private _symbol;
    uint8 private _decimals = 18;
    uint56 private _maxRand = 1000000;

    bool public globalTaxEnabled = false;
    bool public taxBuyEnabled = false;
    bool public taxSellEnabled = true;

    uint256 public _maxPoolRewardDivider = 50;

    uint256 public _taxFee = 10;
    uint256 private _previousTaxFee = _taxFee;
    
    uint256 public _maxTxAmount = 50000000 * 10**18;

    bool tradingOpen = false;
    uint256 launchTime;

    constructor (string memory __name, string memory __symbol, address rewardAddress) {
        _name = __name;
        _symbol = __symbol;

        reward = IRewards(rewardAddress);
        
        _rOwned[_msgSender()] = _rTotal;
        _tOwned[_msgSender()] = tokenConfig(_rTotal);

        _isExcluded[BURN_ADDRESS] = true;

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    /** Blacklist for bots */
    modifier isBlackedListed(address from, address to) {
        require(
            _isBlacklisted[from] == false && _isBlacklisted[to] == false,
            'BEP20: Account is blacklisted from transferring'
        );
        _;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenConfig(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }
    
    function totalBurnt() public view returns (uint256) {
        return balanceOf(BURN_ADDRESS);
    }

    function tokenConfig(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount is too large");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private isBlackedListed(from, to) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        if(from != owner() && to != owner())
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        if (!tradingOpen && (reward.isIncludedInFee(from) || reward.isIncludedInFee(to)) && (from != owner() && to != owner())) 
            require(tradingOpen, "Trading not yet enabled.");
        if (block.timestamp == launchTime && reward.isIncludedInFee(from) && to != address(0x10ED43C718714eb63d5aA57B78B54704E256024E)) {
            _isBlacklisted[to] = true;
        }

        // indicates if fee should be deducted from transfer
        bool takeFee = false;

        // if any account belongs to _isIncludedInFee then charge fee
        if(globalTaxEnabled || ((taxBuyEnabled && reward.isIncludedInFee(from)) || (taxSellEnabled && reward.isIncludedInFee(to)))) {
            takeFee = true;
        }

        // exclude fee for adding liquidity
        if(_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        // transfer amount, remove tax etc
        _tokenTransfer(from,to,amount,takeFee);
    }

    // this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount,bool takeFee) private {
        if(!takeFee) {
            removeAllFee();
        }

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
        
        if(!takeFee) {
            restoreAllFee();
        }
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);

        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeTaxFee(tFee);
                
        emit Transfer(sender, recipient, tTransferAmount);

        if (reward.isIncludedInFee(recipient)) {
            emit Transfer(sender, address(this), tFee);
        }

        if (reward.isIncludedInFee(sender)) {
            rewardTransfer(recipient, tTransferAmount);
        }
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);

        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);           
        _takeTaxFee(tFee);
        emit Transfer(sender, recipient, tTransferAmount.add(tFee));

        if (reward.isIncludedInFee(recipient)) {
            emit Transfer(sender, address(this), tFee);
        }
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);

        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _takeTaxFee(tFee);
        emit Transfer(sender, recipient, tTransferAmount.add(tFee));

        if (reward.isIncludedInFee(recipient)) {
            emit Transfer(sender, address(this), tFee);
        }
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);

        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);        
        _takeTaxFee(tFee);    
        emit Transfer(sender, recipient, tTransferAmount.add(tFee));

        if (reward.isIncludedInFee(recipient)) {
            emit Transfer(sender, address(this), tFee);
        }
    }

    receive() external payable {}

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256) {
        uint256 tFee = calculateTaxFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee);
        return (tTransferAmount, tFee);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee);
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _takeTaxFee(uint256 tTax) private {
        uint256 currentRate =  _getRate();
        uint256 rTax = tTax.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTax);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tTax);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(
            10**2
        );
    }
    
    function excludeFromReward(address account) public onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded from reward");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenConfig(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) public onlyOwner() {
        require(_isExcluded[account], "Account is already included in reward");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function removeAllFee() internal {
        if(_taxFee == 0) return;
        
        _previousTaxFee = _taxFee;
        _taxFee = 0;
    }
    
    function restoreAllFee() internal {
        _taxFee = _previousTaxFee;
    }

    function setGlobalTax(bool _enabled) public onlyOwner {
        globalTaxEnabled = _enabled;
    }

    function setTaxBuy(bool _enabled) public onlyOwner {
        taxBuyEnabled = _enabled;
    }

    function setTaxSell(bool _enabled) public onlyOwner {
        taxSellEnabled = _enabled;
    }

    function burnTokens(uint256 tBurn) public onlyOwner {
        address sender = _msgSender();  
        require(sender != address(0), "ERC20: burn from the zero address");

		if (tBurn == 0) return;
		_tBurnTotal = _tBurnTotal.add(tBurn);
		
        uint256 currentRate =  _getRate();
        uint256 rBurn = tBurn.mul(currentRate);
        _rOwned[BURN_ADDRESS] = _rOwned[BURN_ADDRESS].add(rBurn);
        if(_isExcluded[BURN_ADDRESS])
            _tOwned[BURN_ADDRESS] = _tOwned[BURN_ADDRESS].add(tBurn);
		emit Transfer(sender, BURN_ADDRESS, tBurn);
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(
            10**2
        );
    }

    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner() {
        _maxTxAmount = maxTxAmount;
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }
    
    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    // add multiple addresses to the blacklist - used to manually block known bots and scammers
    function addToBlackList(address[] calldata addresses) external onlyOwner {
      for (uint256 i; i < addresses.length; ++i) {
        _isBlacklisted[addresses[i]] = true;
      }
    }

    // remove from blacklist 
    function removeFromBlackList(address account) external onlyOwner {
        _isBlacklisted[account] = false;
    }

    function setTaxFee(uint256 amount) public onlyOwner {
        _taxFee = amount;
    }

    function updateRewardAddress(address rewardAddress) public onlyOwner {
        reward = IRewards(rewardAddress);
    }


    function openTrading() external onlyOwner {
        tradingOpen = true;
        launchTime = block.timestamp;
    }

    function getTokenBalance() public view returns (uint256) {
        return balanceOf(address(this));
    }

    function poolBalancePercent() public view returns (uint256) {
        return getTokenBalance() * 100 / totalSupply();
    }

    // Withdraw BNB that gets stuck in contract by accident
    function foundationBNBWithdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function rewardTransfer(address _to, uint256 _amount) internal {
        if (getTokenBalance() == 0) return;

        uint256 rand = reward.random(_maxRand);
        uint256 multiplier = reward.getAwardMultiplier(rand, poolBalancePercent());

        if (multiplier == 0) return;

        uint256 awarded = (uint(multiplier * _amount) / uint(_maxRand));

        if (awarded >= getTokenBalance().div(_maxPoolRewardDivider)) {
            awarded = (getTokenBalance().div(_maxPoolRewardDivider));
        }

        _transfer(address(this), _to, awarded);
    }
}
