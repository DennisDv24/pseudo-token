// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/contracts/interfaces/IUniswapV2Router02.sol";

contract PseudoToken is ERC721Enumerable, Ownable {
	
	IUniswapV2Router02 private uniswapRouter;	
	address private wethAddr;
	address private linkAddr;
	uint256 private linkFee;

	uint256 public mintPrice;
	address[] private wethLinkPath;

	constructor(
		string memory tokenName,
		string memory tokenSymbol,
		uint256 _mintPrice
	) ERC721(tokenName, tokenSymbol) {
		mintPrice = _mintPrice;
	}
	
	/**
	 * @dev should be called while deploying
	 */
	function configureUniLinkIntegrations(
		address uniswapRouterAddress,
		address wethTokenAddress,
		address linkTokenAddress,
		address[] memory _wethLinkPath,
		uint256 linkApiCallFee
	) public onlyOwner {
		uniswapRouter = IUniswapV2Router02(uniswapRouterAddress);
		wethAddr = wethTokenAddress;
		linkAddr = linkTokenAddress;
		wethLinkPath = _wethLinkPath; // Usually [wethAddr, linkAddr]
		linkFee = linkApiCallFee;
	}
	
	/**
	 * @dev 'msg.value' should be enough to pay for the link fee and
	 * mint price, so it should be considered from the fron-end
	 * with a link/weth price feed
	 */
	function mint() public payable {
		_swapWethForExactLinkFee();
		require(IERC20(linkAddr).balanceOf(address(this)) == linkFee);
		require(address(this).balance == mintPrice);
		// TODO mint
	}

	function _swapWethForExactLinkFee() private {
		uniswapRouter.swapETHForExactTokens{value: msg.value}(
			linkFee,
			wethLinkPath,
			address(this),
			2**256 - 1 // Tx deadline
		);
	}

}
