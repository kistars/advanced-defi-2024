// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IUniswapV2Pair} from
    "../../../src/interfaces/uniswap-v2/IUniswapV2Pair.sol";
import {IERC20} from "../../../src/interfaces/IERC20.sol";

contract UniswapV2Arb2 {
    struct FlashSwapData {
        // Caller of flashSwap (msg.sender inside flashSwap)
        address caller;
        // Pair to flash swap from
        address pair0;
        // Pair to swap from
        address pair1;
        // True if flash swap is token0 in and token1 out
        bool isZeroForOne;
        // Amount in to repay flash swap
        uint256 amountIn;
        // Amount to borrow from flash swap
        uint256 amountOut;
        // Revert if profit is less than this minimum
        uint256 minProfit;
    }

    // Exercise 1
    // - Flash swap to borrow tokenOut
    /**
     * @param pair0 Pair contract to flash swap
     * @param pair1 Pair contract to swap
     * @param isZeroForOne True if flash swap is token0 in and token1 out
     * @param amountIn Amount in to repay flash swap
     * @param minProfit Minimum profit that this arbitrage must make
     */
    function flashSwap(
        address pair0,
        address pair1,
        bool isZeroForOne,
        uint256 amountIn,
        uint256 minProfit
    ) external {
        // get reserve token amounts from pair0
        (uint112 reserve0, uint112 reserve1,) =
            IUniswapV2Pair(pair0).getReserves();
        // get the amount of token out from pair0
        uint256 amountOut = isZeroForOne
            ? getAmountOut(amountIn, reserve0, reserve1)
            : getAmountOut(amountIn, reserve1, reserve0);
        // encode the params
        bytes memory data = abi.encode(
            FlashSwapData({
                caller: msg.sender,
                pair0: pair0,
                pair1: pair1,
                isZeroForOne: isZeroForOne,
                amountIn: amountIn,
                amountOut: amountOut,
                minProfit: minProfit
            })
        );
        // falsh swap
        IUniswapV2Pair(pair0).swap({
            amount0Out: isZeroForOne ? 0 : amountOut,
            amount1Out: isZeroForOne ? amountOut : 0,
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
        FlashSwapData memory params = abi.decode(data, (FlashSwapData));
        require(msg.sender == params.pair0, "invalid msg sender");
        // 闪电贷中的in和out
        (address tokenIn, address tokenOut) = params.isZeroForOne
            ? (
                IUniswapV2Pair(params.pair0).token0(),
                IUniswapV2Pair(params.pair0).token1()
            )
            : (
                IUniswapV2Pair(params.pair0).token1(),
                IUniswapV2Pair(params.pair0).token0()
            );

        // swap from pair1
        // transfer token to pair1
        // 第一步的输出作为第二步的输入
        (uint112 reserve0, uint112 reserve1,) =
            IUniswapV2Pair(params.pair1).getReserves();
        uint256 amountOut = params.isZeroForOne
            ? getAmountOut(params.amountOut, reserve1, reserve0)
            : getAmountOut(params.amountOut, reserve0, reserve1);

        IERC20(tokenOut).transfer(params.pair1, params.amountOut);

        IUniswapV2Pair(params.pair1).swap({
            amount0Out: params.isZeroForOne ? amountOut : 0,
            amount1Out: params.isZeroForOne ? 0 : amountOut,
            to: address(this),
            data: ""
        });
        // get the profit
        uint256 profit = amountOut - params.amountIn;
        require(profit > params.minProfit, "profit < min");
        // repay by tokenIn
        IERC20(tokenIn).transfer(params.pair0, params.amountIn);
        // transfer profit
        IERC20(tokenIn).transfer(params.caller, profit);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
}
