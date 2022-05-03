const Exchange = artifacts.require("Exchange");
const Token = artifacts.require("Token");
const { expect } = require("chai");
require("chai").use(require("chai-as-promised")).should();

const toWei = (value) => web3.utils.toWei(value.toString(), "ether");

const getBalance = (address) => web3.eth.getBalance(address);

const fromWei = (value) =>
  web3.utils.fromWei(
    typeof value === "string" ? value : value.toString(),
    "ether"
  );

contract("Exchange", ([deployer, ...accounts]) => {
  let owner;
  let user;
  let token;
  let exchange;

  beforeEach(async () => {
    owner = deployer;
    user = accounts[1];

    token = await Token.new("Token", "TKN", toWei(1000000));
    exchange = await Exchange.new(token.address);
  });
  it("is deployed", async () => {
    expect(await exchange.tokenAddress()).to.equal(token.address);
  });

  describe("addLiquidity", async () => {
    it("adds liquidity", async () => {
      await token.approve(exchange.address, toWei(200));
      await exchange.addLiquidity(toWei(200), { value: toWei(10) });

      const balanceOf = await getBalance(exchange.address);
      const reserve = await exchange.getReserve();
      expect(balanceOf.toString(), toWei(10));
      expect(reserve.toString()).to.equal(toWei(200));
    });
  });

  describe("getPrice", async () => {
    it("returns correct prices", async () => {
      await token.approve(exchange.address, toWei(20));
      await exchange.addLiquidity(toWei(20), { value: toWei(10) });

      const tokenReserve = await exchange.getReserve();
      const etherReserve = await getBalance(exchange.address);

      const priceEthPerTkn = await exchange.getPrice(
        etherReserve,
        tokenReserve
      );
      const priceTknPerEth = await exchange.getPrice(
        tokenReserve,
        etherReserve
      );
      expect(priceEthPerTkn.toString()).to.equal("500");
      expect(priceTknPerEth.toString()).to.equal("2000");
    });
  });

  describe("getTokenAmount", async () => {
    it("returns correct token amount", async () => {
      await token.approve(exchange.address, toWei(20));
      await exchange.addLiquidity(toWei(20), { value: toWei(10) });

      const tokensOut = await exchange.getTokenAmount(toWei(1));
      expect(fromWei(tokensOut)).to.equal("1.818181818181818181");
    });
  });

  describe("getEthAmount", async () => {
    it("returns correct eth amount", async () => {
      await token.approve(exchange.address, toWei(20));
      await exchange.addLiquidity(toWei(20), { value: toWei(10) });

      const ethOut = await exchange.getEthAmount(toWei(2));
      expect(fromWei(ethOut)).to.equal("0.90909090909090909");
    });
  });

  describe("ethToTokenSwap", async () => {
    beforeEach(async () => {
      await token.approve(exchange.address, toWei(20));
      await exchange.addLiquidity(toWei(20), { value: toWei(10) });
    });

    it("transfers at least min amount of tokens", async () => {
      const userBalanceBefore = await getBalance(user);

      await exchange.ethToTokenSwap(toWei(1.8), {
        from: user,
        value: toWei(1),
      });

      const userBalanceAfter = await getBalance(user);
      expect(fromWei(userBalanceAfter - userBalanceBefore)).to.equal(
        "-1.0011875599999959"
      );

      const userTokenBalance = await token.balanceOf(user);
      expect(fromWei(userTokenBalance)).to.equal("1.818181818181818181");

      const exchangeEthBalance = await getBalance(exchange.address);
      expect(fromWei(exchangeEthBalance)).to.equal("11");

      const exchangeTokenBalance = await token.balanceOf(exchange.address);
      expect(fromWei(exchangeTokenBalance)).to.equal("18.181818181818181819");
    });

    it("fails when output amount is less than min amount", async () => {
      await exchange
        .ethToTokenSwap(toWei(2), { from: user, value: toWei(1) })
        .should.be.rejectedWith("insufficient output amount");
    });

    it("allows zero swaps", async () => {
      await exchange.ethToTokenSwap(toWei(0), {
        from: user,
        value: toWei(0),
      });
      //console.log(bought);
      const userTokenBalance = await token.balanceOf(user);
      expect(fromWei(userTokenBalance)).to.equal("0");

      const exchangeEthBalance = await getBalance(exchange.address);
      expect(fromWei(exchangeEthBalance)).to.equal("10");

      const exchangeTokenBalance = await token.balanceOf(exchange.address);
      expect(fromWei(exchangeTokenBalance)).to.equal("20");
    });
  });
});
