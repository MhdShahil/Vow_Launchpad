// LIBRARIES
const { expect } = require("chai");

const {
  expectEvent,
  expectRevert,
  constants,
  time,
  ether,
} = require("@openzeppelin/test-helpers");
const { BN, expectInvalidArgument } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const { ZERO_ADDRESS } = constants;
// CONTRACTS
const PriceOracleContract = artifacts.require("PriceOracle");
contract("PriceOracle", function () {
  let priceOracle;
  beforeEach(async () => {
    priceOracle = await PriceOracleContract.new();
  });
  describe("1.On deployment", async function () {
    it("1.1. should set price feed", async function () {
      const Receipt = await priceOracle.setPriceFeedAddress(
        "BUSD",
        "0x4Fabb145d64652a948d72533023f6E7A623C7C53",
        "0x833d8eb16d306ed1fbb5d7a2e019e106b960965a"
      );
    });
    it("1.2. should return price feed in USD", async function () {
      const Receipt = await priceOracle.setPriceFeedAddress(
        "BUSD",
        "0x4Fabb145d64652a948d72533023f6E7A623C7C53",
        "0x833d8eb16d306ed1fbb5d7a2e019e106b960965a"
      );
      const price = await priceOracle.getTokenPrice(
        "0x4Fabb145d64652a948d72533023f6E7A623C7C53"
      );
    });
  });
});
