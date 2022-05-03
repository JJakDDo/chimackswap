// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "@klaytn/contracts/token/KIP7/IKIP7.sol";

contract Exchange {
  address public tokenAddress;

  constructor (address _token) public {
    require(_token != address(0), "invalid token address");

    tokenAddress = _token;
  }

  function addLiquidity(uint256 _tokenAmount) public payable {
    IKIP7 token = IKIP7(tokenAddress);
    token.transferFrom(msg.sender, address(this), _tokenAmount);
  }

  function getReserve() public view returns (uint256) {
    return IKIP7(tokenAddress).balanceOf(address(this));
  }

  function getPrice(uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
    require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

    return (inputReserve * 1000) / outputReserve;
  }

  function getAmount(
    uint256 inputAmount,
    uint256 inputReserve,
    uint256 outputReserve
  ) private pure returns (uint256){
    require(inputReserve > 0 && outputReserve > 0, "invalid reserves");

    return (inputAmount * outputReserve) / (inputReserve + inputAmount);
  }

  function getTokenAmount(uint256 _ethSold) public view returns (uint256){
    require(_ethSold > 0, "ethSold is too small");

    uint256 tokenReserve = getReserve();

    return getAmount(_ethSold, address(this).balance, tokenReserve);
  }

  function getEthAmount(uint256 _tokenSold) public view returns (uint256) {
    require(_tokenSold > 0, "tokenSold is too small");

    uint256 tokenReserve = getReserve();

    return getAmount(_tokenSold, tokenReserve, address(this).balance);
  }

  function ethToTokenSwap(uint256 _minTokens) public payable returns(uint256) {
    uint256 tokenReserve = getReserve();
    uint256 tokensBought = getAmount(
      msg.value,
      address(this).balance - msg.value,
      tokenReserve
    );
    require(tokensBought >= _minTokens, "insufficient output amount");

    IKIP7(tokenAddress).transfer(msg.sender, tokensBought);
  }

  function tokenToEthSwap(uint256 _tokensSold, uint256 _minEth) public {
    uint256 tokenReserve = getReserve();
    uint256 ethBought = getAmount(
      _tokensSold,
      tokenReserve,
      address(this).balance
    );

    require(ethBought >= _minEth, "insufficient output amount");

    IKIP7(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
    //0.6.0 이상부터 payable
    //payable(msg.sender).transfer(ethBought);
    msg.sender.transfer(ethBought);
  }
}