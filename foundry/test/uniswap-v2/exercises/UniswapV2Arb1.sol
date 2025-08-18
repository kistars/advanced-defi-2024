// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IUniswapV2Pair} from
    "../../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from
    "../../../src/interfaces/uniswap-v2/IUniswapV2Router02.sol";
import {IERC20} from "../../../src/interfaces/IERC20.sol";

contract UniswapV2Arb1 {
    struct SwapParams {
        // Router to execute first swap - tokenIn for tokenOut
        address router0;
        // Router to execute second swap - tokenOut for tokenIn
        address router1;
        // Token in of first swap
        address tokenIn;
        // Token out of first swap
        address tokenOut;
        // Amount in for the first swap
        uint256 amountIn;
        // Revert the arbitrage if profit is less than this minimum
        uint256 minProfit;
    }

    // Exercise 1
    // - Execute an arbitrage between router0 and router1
    // - Pull tokenIn from msg.sender
    // - Send amountIn + profit back to msg.sender
    function swap(SwapParams calldata params) external {
        // Write your code here
        // Don’t change any other code
        IERC20(params.tokenIn).transferFrom(
            msg.sender, address(this), params.amountIn
        );
        // swap router0
        address[] memory path = new address[](2);
        path[0] = params.tokenIn;
        path[1] = params.tokenOut;
        uint256[] memory amounts1 = IUniswapV2Router02(params.router0)
            .swapExactTokensForTokens({
            amountIn: params.amountIn,
            amountOutMin: 1,
            path: path,
            to: address(this),
            deadline: block.timestamp
        });
        require(amounts1.length == 2, "invalid amounts length");

        // swap router1
        path[0] = params.tokenOut;
        path[1] = params.tokenIn;
        uint256[] memory amounts2 = IUniswapV2Router02(params.router1)
            .swapExactTokensForTokens({
            amountIn: amounts1[1],
            amountOutMin: 1,
            path: path,
            to: address(this),
            deadline: block.timestamp
        });

        uint256 profit = amounts2[1] - params.amountIn;
        require(profit > params.minProfit, "less profit");

        IERC20(params.tokenIn).transfer(msg.sender, params.amountIn + profit);
    }

    // Exercise 2
    // - Execute an arbitrage between router0 and router1 using flash swap
    // - Borrow tokenIn with flash swap from pair
    // - Send profit back to msg.sender
    /**
     * @param pair Address of pair contract to flash swap and borrow tokenIn
     * @param isToken0 True if token to borrow is token0 of pair
     * @param params Swap parameters
     */
    function flashSwap(address pair, bool isToken0, SwapParams calldata params)
        external
    {
        // Write your code here
        // Don’t change any other code
        (uint256 amount0Out, uint256 amount1Out) = isToken0
            ? (params.amountIn, uint256(0))
            : (uint256(0), params.amountIn);
        bytes memory data = abi.encode(params.tokenOut, msg.sender);
        IUniswapV2Pair(pair).swap({
            amount0Out: amount0Out,
            amount1Out: amount1Out,
            to: address(this),
            data: data
        });
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0Out,
        uint256 amount1Out,
        bytes calldata data
    ) external {
        // Write your code here
        // Don’t change any other code
        require(sender == address(this), "invalid sender");

        (address token, address caller) = abi.decode(data, (address, address));

        require(amount0Out > 0 || amount1Out > 0, "invalid amount out");
        if (amount0Out > 0 && amount1Out > 0) {
            revert("both greater than 0");
        }
        uint256 amount = amount0Out > 0 ? amount0Out : amount1Out;

        // fee
        uint256 fee = amount * 3 / 997 + 1;
        uint256 amountRepay = amount + fee;

        IERC20(token).transferFrom(caller, address(this), fee);
        IERC20(token).transfer(address(caller), amountRepay);
    }
}
