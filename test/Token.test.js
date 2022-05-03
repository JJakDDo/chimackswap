const Token = artifacts.require("Token");
const { expect } = require("chai");

contract("Token", ([deployer, ...accounts]) => {
  let owner;
  let token;

  before(async () => {
    owner = deployer;

    token = await Token.new("Token", "TKN", 31337);
  });

  it("sets name and symbol when created", async () => {
    expect(await token.name()).to.equal("Token");
    expect(await token.symbol()).to.equal("TKN");
  });

  it("mints initialSupply to msg.sender when created", async () => {
    const totalSupply = await token.totalSupply();
    const balanceOf = await token.balanceOf(owner);

    expect(totalSupply.toString()).to.equal("31337");
    expect(balanceOf.toString()).to.equal("31337");
  });
});
