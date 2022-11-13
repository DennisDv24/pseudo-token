// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/contracts/interfaces/IUniswapV2Router02.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract PseudoToken is ERC721Enumerable, Ownable, ChainlinkClient {
	
	using Chainlink for Chainlink.Request;

	uint256 public mintPrice;
	uint256 public linkFee;
	mapping (uint256 => string) public tokenIdToTwit;

	IUniswapV2Router02 private uniswapRouter;	
	address private wethAddr;
	address private linkAddr;
	address[] private wethLinkPath;

	bytes32 private jobId;
	mapping (bytes32 => uint256) private requestIdToTokenId;

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
		address[] memory _wethLinkPath
	) public onlyOwner {
		uniswapRouter = IUniswapV2Router02(uniswapRouterAddress);
		wethAddr = wethTokenAddress;
		linkAddr = linkTokenAddress;
		wethLinkPath = _wethLinkPath; // Usually [wethAddr, linkAddr]
	}

	/**
	 * @dev should be called while deploying
	 */
	function configureChainlinkClient(
		uint256 linkApiCallFee,
		address chainlinkOracle,
		bytes32 chainlinkJobId
	) public onlyOwner {
		linkFee = linkApiCallFee;
		require(
			linkAddr != address(0),
			"ERROR: Contract integration should be first configured"
		);
		setChainlinkToken(linkAddr);
		setChainlinkOracle(chainlinkOracle);
		jobId = chainlinkJobId;
	}
	
	/**
	 * @dev 'msg.value' should be enough to pay for the link fee and
	 * mint price, so it should be considered from the fron-end
	 * with a link/weth price feed.
	 * @notice ownership of 'twitterName' should be verified.
	 */
	function mint(string memory twitterName) public payable {
		_swapWethForExactLinkFee();
		require(IERC20(linkAddr).balanceOf(address(this)) == linkFee);
		require(address(this).balance == mintPrice);
		_safeMint(msg.sender, totalSupply() + 1);
		_getPinnedTwit(twitterName);
	}

	function _swapWethForExactLinkFee() private {
		uniswapRouter.swapETHForExactTokens{value: msg.value}(
			linkFee,
			wethLinkPath,
			address(this),
			2**256 - 1 // Tx deadline
		);
	}

	function _getPinnedTwit(string memory twitterName) private {
		Chainlink.Request memory req = buildChainlinkRequest(
			jobId, address(this), this.fulfill.selector
		);
		req.add('get', _getPinnedTwitEndpoint(twitterName));
		// TODO req.add('path', ...);
		bytes32 reqId = sendChainlinkRequest(req, linkFee);
		requestIdToTokenId[reqId] = totalSupply();
	}

	// TODO
	function _getPinnedTwitEndpoint(
		string memory twitterName
	) private returns (string memory) {
		return "";
	}

	function fulfill(bytes32 reqId, string memory twit) 
		public
		recordChainlinkFulfillment(reqId)
	{
		tokenIdToTwit[requestIdToTokenId[reqId]] = twit;
	}

}
