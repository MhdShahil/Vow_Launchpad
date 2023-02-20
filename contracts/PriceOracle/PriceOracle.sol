// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../common/VOWControl.sol";

contract PriceOracle is VOWControl {
    //AggregatorV3Interface internal priceFeed;

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
    ) external {
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
        require(_tokenAddress != address(0), "PriceFeeds : Invalid Address");
        require(
            getInfoByTokenAddress[_tokenAddress].exists,
            "PriceFeeds : Coin doesn't exists"
        );
        AggregatorV3Interface priceFeed;
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

    function calculateTokensToVow(uint256 _amount) public view returns (int) {}
}
