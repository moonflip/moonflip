// SPDX-License-Identifier: MIT

/*
* ███    ███  ██████   ██████  ███    ██ ███████ ██      ██ ██████  
* ████  ████ ██    ██ ██    ██ ████   ██ ██      ██      ██ ██   ██ 
* ██ ████ ██ ██    ██ ██    ██ ██ ██  ██ █████   ██      ██ ██████  
* ██  ██  ██ ██    ██ ██    ██ ██  ██ ██ ██      ██      ██ ██      
* ██      ██  ██████   ██████  ██   ████ ██      ███████ ██ ██      
*
* Website: https://www.moonflip.net/
* Twitter: https://twitter.com/moonfliptoken
* Discord: https://discord.gg/moonfliptoken
* Reddit: https://www.reddit.com/r/moonfliptoken/
* Telegram: https://t.me/moonfliptoken
*/

import './interfaces/IERC20.sol';
import './interfaces/IRewardSheet.sol';
import './interfaces/IOracle.sol';
import './interfaces/AggregatorInterface.sol';
import './library/SafeMath.sol';
import "@openzeppelin/contracts/access/AccessControl.sol";


pragma solidity >=0.6.12;

contract Rewards is Context, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant READ_ROLE = keccak256("READ_ROLE");

    IOracle oracle;
    IRewardSheet rewardSheet;
    AggregatorInterface private priceData;

    mapping (address => bool) private _isTaxedTradingPair;

    uint56 private _maxRand = 1000000;
    uint256 private _incremeter = 0;
    uint256 private _poolGrowthPercent = 20;
    
    bool public rewardsEnabled = false;

    constructor(address _oracleAddress, address _rewardSheetAddress, address _priceData) {
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(READ_ROLE, msg.sender);

        oracle = IOracle(_oracleAddress);
        rewardSheet = IRewardSheet(_rewardSheetAddress);
        priceData = AggregatorInterface(_priceData);
    }

    function setRewardSheetAddress(address _rewardSheetAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");
        
        rewardSheet = IRewardSheet(_rewardSheetAddress);
    }

    function setPriceDataAddress(address _priceData) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");
        
        priceData = AggregatorInterface(_priceData);
    }

    function addAdmin(address newAdmin) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");
        
        _setupRole(ADMIN_ROLE, newAdmin);
    }

    function addReader(address reader) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");
        
        _setupRole(READ_ROLE, reader);
    }

    function getAwardMultiplier(uint256 rand, uint256 percent) external view returns(uint256) {
        if (percent <= 20) {
            return rewardSheet.getPoolGrowthAwardMultiplier(rand);
        }
        
        return rewardSheet.getAwardMultiplier(rand);
    }

    function resetIncrementer() public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        _incremeter = 0;
    }

    function setPoolGrowthPercent(uint256 poolGrowthPercent) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        _poolGrowthPercent = poolGrowthPercent;
    }

    function setRewardsEnabled(bool active) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        rewardsEnabled = active;
    }

    function excludeFromFee(address account) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        _isTaxedTradingPair[account] = false;
    }
    
    function includeInFee(address account) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        _isTaxedTradingPair[account] = true;
    }

    function isIncludedInFee(address account) external view returns (bool) {
        if (!rewardsEnabled) return false;

        return _isTaxedTradingPair[account];
    }

    function updateOracleAddress(address oracleAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        oracle = IOracle(oracleAddress);
    }

    function random(uint max) external returns(uint) {
        require(hasRole(READ_ROLE, msg.sender), "Caller is not READER");

        bytes memory source;
        uint oracleRandom = oracle.getRandom();
        int256 price = priceData.latestAnswer();

        _incremeter++;

        source = abi.encodePacked(
            oracleRandom,
            _incremeter,
            price,
            block.timestamp,
            block.number,
            blockhash(block.number),
            block.difficulty,
            msg.sender
        );

        uint rand = (uint(keccak256(source)).mod(max));

        return rand;
    }
}