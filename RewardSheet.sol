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

pragma solidity >=0.6.12;


contract RewardSheet {
    function getAwardMultiplier(uint256 rand) external pure returns(uint256) {
        if (rand <= 500000) return 0;
        else if (rand <= 765000) return 100000;
        else if (rand <= 911500) return 200000;
        else if (rand <= 956500) return 300000;
        else if (rand <= 984000) return 500000;
        else if (rand <= 996500) return 1000000;
        else if (rand <= 999000) return 2000000;
        else if (rand <= 1000000) return 4000000;
        else return 0;
    }

    function getPoolGrowthAwardMultiplier(uint256 rand) external pure returns(uint256) {
        if (rand <= 500000) return 0;
        else if (rand <= 780000) return 100000;
        else if (rand <= 921500) return 200000;
        else if (rand <= 961500) return 300000;
        else if (rand <= 986500) return 500000;
        else if (rand <= 996500) return 1000000;
        else if (rand <= 999000) return 2000000;
        else if (rand <= 1000000) return 4000000;
        else return 0;
    }
}