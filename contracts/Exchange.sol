// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "@klaytn/contracts/token/KIP7/IKIP7.sol";
import "@klaytn/contracts/token/KIP7/KIP7Token.sol";

interface IExchange {
    function ethToTokenSwap(uint256 _minTokens) external payable;

    function ethToTokenTransfer(uint256 _minTokens, address _recipient)
        external
        payable;
}

interface IFactory {
    function getExchange(address _tokenAddress) external returns (address);
}

contract Exchange is KIP7Token{
  address public tokenAddress;
  address public factoryAddress;

  constructor (address _token) KIP7Token("Chimackswap-V1", "CHIMACK", 18, 0) public {
    require(_token != address(0), "invalid token address");

    tokenAddress = _token;
    factoryAddress = msg.sender;
  }

  function addLiquidity(uint256 _tokenAmount) public payable returns (uint256){
    if(getReserve() == 0){
      IKIP7 token = IKIP7(tokenAddress);
      token.transferFrom(msg.sender, address(this), _tokenAmount);

      uint256 liquidity = address(this).balance;
      _mint(msg.sender, liquidity);
    } else {
      uint256 ethReserve = address(this).balance - msg.value;
      uint256 tokenReserve = getReserve();
      uint256 tokenAmount = (msg.value * tokenReserve) / ethReserve;
      require(_tokenAmount >= tokenAmount, "insufficient token amount");

      IKIP7 token = IKIP7(tokenAddress);
      token.transferFrom(msg.sender, address(this), tokenAmount);

      uint256 liquidity = (totalSupply() * msg.value) / ethReserve;
      _mint(msg.sender, liquidity);

      return liquidity;
    }
  }

  function removeLiquidity(uint256 _amount) public returns (uint256 ,uint256) {
    require(_amount > 0, "invalid amount");

    uint256 ethAmount = (address(this).balance * _amount) / totalSupply();
    uint256 tokenAmount = (getReserve() * _amount) / totalSupply();

    _burn(msg.sender, _amount);
    msg.sender.transfer(ethAmount);
    IKIP7(tokenAddress).transfer(msg.sender, tokenAmount);

    return (ethAmount, tokenAmount);
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

    uint256 inputAmountWithFee = inputAmount * 99;
    uint256 numerator = inputAmountWithFee * outputReserve;
    uint256 denominator = (inputReserve * 100) + inputAmountWithFee;

    return numerator / denominator;
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

  function ethToToken(uint256 _minTokens, address recipient) private {
    uint256 tokenReserve = getReserve();
    uint256 tokensBought = getAmount(
      msg.value,
      address(this).balance - msg.value,
      tokenReserve
    );
    require(tokensBought >= _minTokens, "insufficient output amount");

    IKIP7(tokenAddress).transfer(recipient, tokensBought);
  }

  function ethToTokenSwap(uint256 _minTokens) public payable {
    ethToToken(_minTokens, msg.sender);
  }

  function ethToTokenTransfer(uint256 _minTokens, address _recipient) public payable {
    ethToToken(_minTokens, _recipient);
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

  function tokenToTokenSwap(
    uint256 _tokensSold,
    uint256 _minTokensBought,
    address _tokenAddress
  ) public {
    address exchangeAddress = IFactory(factoryAddress).getExchange(_tokenAddress);
    uint256 tokenReserve = getReserve();
    uint256 ethBought = getAmount(
      _tokensSold,
      tokenReserve,
      address(this).balance
    );

    IKIP7(tokenAddress).transferFrom(msg.sender, address(this), _tokensSold);

    IExchange(exchangeAddress).ethToTokenTransfer.value(ethBought)(_minTokensBought, msg.sender);
  }
}