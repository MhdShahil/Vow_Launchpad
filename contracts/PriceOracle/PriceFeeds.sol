// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./common/VOWControl.sol";

contract PriceConsumerV3 {
    AggregatorV3Interface internal priceFeed;

    struct StableCoin {
        string name;
        address priceFeedAddress;
        bool exists;
    }
    mapping(address => StableCoin) public getInfoByTokenAddress;

    function setPriceFeedAddress(
        string memory _name,
        address _tokenAddress,
        address _priceFeedAddress
    ) external onlyVowAdmin {
        getInfoByTokenAddress[_tokenAddress] = StableCoin(
            _name,
            _priceFeedAddress,
            true
        );
    }

    /**
     * Returns the latest price.
     */

    function getTokenPrice(address _tokenAddress) public view returns (int) {
        require(
            getInfoByTokenAddress[_tokenAddress] != address(0),
            "PriceFeeds : Invalid Address"
        );
        require(
            getInfoByTokenAddress[_tokenAddress].exists,
            "PriceFeeds : Coin doesn't exists"
        );
        priceFeed = AggregatorV3Interface(
            getInfoByTokenAddress[_tokenAddress].priceFeedAddress
        );
        (
            ,
            /* uint80 roundID */ int price /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/,
            ,
            ,

        ) = priceFeed.latestRoundData();
        return price;
    }
}
