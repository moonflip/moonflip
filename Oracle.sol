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

import './library/SafeMath.sol';
import './interfaces/AggregatorInterface.sol';
import "@openzeppelin/contracts/access/AccessControl.sol";

pragma solidity >=0.6.12;


contract Oracle is Context, AccessControl {
    using SafeMath for uint256;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant READ_ROLE = keccak256("READ_ROLE");
    uint256 private constant MAX = 32767;

    uint[] private rand;
    AggregatorInterface private priceData;

    constructor(address _priceData, uint[] memory _rand) public {
        rand = _rand;
        priceData = AggregatorInterface(_priceData);
        
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(READ_ROLE, msg.sender);
    }

    function addAdmin(address newAdmin) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");
        
        _setupRole(ADMIN_ROLE, newAdmin);
    }

    function addReader(address reader) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");
        
        _setupRole(READ_ROLE, reader);
    }

    function addRand(uint[] memory _rand) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        for (uint i=0; i < _rand.length; i++) {
            rand.push(_rand[i]);
        }
    }

    function setRand(uint[] memory _rand) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        rand = _rand;
    }

    function feedRandomness(uint[] memory _rand) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        rand = _rand;
    }
    
    function getRandomOracle(uint entropy) internal view returns(uint) {
        bytes memory source = abi.encodePacked(
            entropy,
            block.timestamp,
            block.number,
            blockhash(block.number),
            block.difficulty,
            msg.sender
        );
        
        uint random = uint(keccak256(source)).mod(rand.length);
        
        return rand[random];
    }
    
    function mixRandom(uint256 count) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not ADMIN");

        uint len = count;
        if (count == 0)
            len = rand.length;
        
        for (uint i=0; i < len; i++) {
            uint baseOracle = rand[i];

            bytes memory source = abi.encodePacked(
                baseOracle,
                block.timestamp,
                block.number,
                blockhash(block.number),
                block.difficulty,
                msg.sender,
                i
            );
            
            rand[i] = uint(keccak256(source)).mod(MAX);
        }
    }
    
    function getRandom() external view returns(uint) {
        require(hasRole(READ_ROLE, msg.sender), "Caller is not READER");
        
        bytes memory source;
        int256 price = priceData.latestAnswer();
        
        uint i;
        uint oracleRandom;
        for (i=0; i < 5; i++) {
            source = abi.encodePacked(
                oracleRandom,
                block.timestamp,
                block.number,
                blockhash(block.number),
                block.difficulty,
                msg.sender,
                source,
                i,
                price
            );
            
            oracleRandom = getRandomOracle(uint(keccak256(source)));
        }

        return uint(keccak256(source));
    }
}