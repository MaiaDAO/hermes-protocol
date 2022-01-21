

![alt text](Solidly-Logo_Dark.png)


Solidly allows low cost, near 0 slippage trades on uncorrelated or tightly correlated assets. The protocol incentivizes fees instead of liquidity. Liquidity providers (LPs) are given incentives in the form of `token`, the amount received is calculated as follows;

* 100% of weekly distribution weighted on votes from ve-token holders

The above is distributed to the `gauge` (see below), however LPs will earn between 40% and 100% based on their own ve-token balance.

LPs with 0 ve* balance, will earn a maximum of 40%.

## AMM

What differentiates Solidly's AMM;

Solidly AMMs are compatible with all the standard features as popularized by Uniswap V2, these include;

* Lazy LP management
* Fungible LP positions
* Chained swaps to route between pairs
* priceCumulativeLast that can be used as external TWAP
* Flashloan proof TWAP
* Direct LP rewards via `skim`
* xy>=k

Solidly adds on the following features;

* 0 upkeep 30 minute TWAPs. This means no additional upkeep is required, you can quote directly from the pair
* Fee split. Fees do not auto accrue, this allows external protocols to be able to profit from the fee claim
* New curve: x3y+y3x, which allows efficient stable swaps
* Curve quoting: `y = (sqrt((27 a^3 b x^2 + 27 a b^3 x^2)^2 + 108 x^12) + 27 a^3 b x^2 + 27 a b^3 x^2)^(1/3)/(3 2^(1/3) x) - (2^(1/3) x^3)/(sqrt((27 a^3 b x^2 + 27 a b^3 x^2)^2 + 108 x^12) + 27 a^3 b x^2 + 27 a b^3 x^2)^(1/3)`
* Routing through both stable and volatile pairs
* Flashloan proof reserve quoting

## token

**TBD**

## ve-token

Vested Escrow (ve), this is the core voting mechanism of the system, used by `BaseV1Factory` for gauge rewards and gauge voting.

This is based off of ve(3,3) as proposed [here](https://andrecronje.medium.com/ve-3-3-44466eaa088b)

* `deposit_for` deposits on behalf of
* `emit Transfer` to allow compatibility with third party explorers
* balance is moved to `tokenId` instead of `address`
* Locks are unique as NFTs, and not on a per `address` basis

```
function balanceOfNFT(uint) external returns (uint)
```

## BaseV1Pair

Base V1 pair is the base pair, referred to as a `pool`, it holds two (2) closely correlated assets (example MIM-UST) if a stable pool or two (2) uncorrelated assets (example FTM-SPELL) if not a stable pool, it uses the standard UniswapV2Pair interface for UI & analytics compatibility.

```
function mint(address to) external returns (uint liquidity)
function burn(address to) external returns (uint amount0, uint amount1)
function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external
```

Functions should not be referenced directly, should be interacted with via the BaseV1Router

Fees are not accrued in the base pair themselves, but are transfered to `BaseV1Fees` which has a 1:1 relationship with `BaseV1Pair`

### BaseV1Factory

Base V1 factory allows for the creation of `pools` via ```function createPair(address tokenA, address tokenB, bool stable) external returns (address pair)```

Base V1 factory uses an immutable pattern to create pairs, further reducing the gas costs involved in swaps

Anyone can create a pool permissionlessly.

### BaseV1Router

Base V1 router is a wrapper contract and the default entry point into Stable V1 pools.

```

function addLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) external ensure(deadline) returns (uint amountA, uint amountB, uint liquidity)

function removeLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint liquidity,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
) public ensure(deadline) returns (uint amountA, uint amountB)

function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    route[] calldata routes,
    address to,
    uint deadline
) external ensure(deadline) returns (uint[] memory amounts)

```

## Gauge

Gauges distribute arbitrary `token(s)` rewards to BaseV1Pair LPs based on voting weights as defined by `ve` voters.

Arbitrary rewards can be added permissionlessly via ```function notifyRewardAmount(address token, uint amount) external```

Gauges are completely overhauled to separate reward calculations from deposit and withdraw. This further protect LP while allowing for infinite token calculations.

Previous iterations would track rewardPerToken as a shift everytime either totalSupply, rewardRate, or time changed. Instead we track each individually as a checkpoint and then iterate and calculation.

## Bribe

Gauge bribes are natively supported by the protocol, Bribes inherit from Gauges and are automatically adjusted on votes.

Users that voted can claim their bribes via calling ```function getReward(address token) public```

Fees accrued by `Gauges` are distributed to `Bribes`

### BaseV1Voter

Gauge factory permissionlessly creates gauges for `pools` created by `BaseV1Factory`. Further it handles voting for 100% of the incentives to `pools`.

```
function vote(address[] calldata _poolVote, uint[] calldata _weights) external
function distribute(address token) external
```

### Testnet deployment

| Name | Address |
| :--- | :--- |
| wFTM| [0x27Ce41c3cb9AdB5Edb2d8bE253A1c6A64Db8c96d](https://testnet.ftmscan.com/address/0x27Ce41c3cb9AdB5Edb2d8bE253A1c6A64Db8c96d#code) |
| USDT| [0x8ad96050318043166114884b59E2fc82210273b3](https://testnet.ftmscan.com/address/0x8ad96050318043166114884b59E2fc82210273b3#code) |
| MIM | [0x976e33B07565b0c05B08b2e13AfFD3113e3D178d](https://testnet.ftmscan.com/address/0x976e33B07565b0c05B08b2e13AfFD3113e3D178d#code) |
| BaseV1Factory | [0x5Ea8dfc4D2e033C509DbFE04Ec06C528Dc8390E6](https://testnet.ftmscan.com/address/0x5Ea8dfc4D2e033C509DbFE04Ec06C528Dc8390E6#code) |
| BaseV1Router01 | [0xb4c16C699F77cA5286998B47C658D0AEdC857dA3](https://testnet.ftmscan.com/address/0xb4c16C699F77cA5286998B47C658D0AEdC857dA3#code) |
| BaseV1 | [0x0673e1CF8EE91095232CFC98Ee1EbCeF42A1977E](https://testnet.ftmscan.com/address/0x0673e1CF8EE91095232CFC98Ee1EbCeF42A1977E#code) |
| tokenizer | [0x3092326DB3220b5102A2999e8A5e80cd7503E1b5](https://testnet.ftmscan.com/address/0x3092326DB3220b5102A2999e8A5e80cd7503E1b5#code) |
| ve3 | [0x81068A3eD5535c78884c7Ca566985c99069E5f81](https://testnet.ftmscan.com/address/0x81068A3eD5535c78884c7Ca566985c99069E5f81#code) |
| ve3-dist | [0xc5da94535278c6410d8864009D67807cD26FE88A](https://testnet.ftmscan.com/address/0xc5da94535278c6410d8864009D67807cD26FE88A#code) |
| BaseV1GaugesFactory | [0xa7f86ceac917fBcd6005eDB7FE5047C75Ac0aC42](https://testnet.ftmscan.com/address/0xa7f86ceac917fBcd6005eDB7FE5047C75Ac0aC42#code) ||
| BaseV1GaugesVoter | [0x8C29427Bfa0f46Ab11066Df10D74cAEB363b4904](https://testnet.ftmscan.com/address/0x8C29427Bfa0f46Ab11066Df10D74cAEB363b4904#code) |
| BaseV1Minter | [0xAE27B2DdBFd2D3b25898f769499CCd9c8DBc712b](https://testnet.ftmscan.com/address/0xAE27B2DdBFd2D3b25898f769499CCd9c8DBc712b#code) |

### Previous Testnet deployment

| Name | Address |
| :--- | :--- |
| wFTM| [0x27Ce41c3cb9AdB5Edb2d8bE253A1c6A64Db8c96d](https://testnet.ftmscan.com/address/0x27Ce41c3cb9AdB5Edb2d8bE253A1c6A64Db8c96d#code) |
| USDT| [0x8ad96050318043166114884b59E2fc82210273b3](https://testnet.ftmscan.com/address/0x8ad96050318043166114884b59E2fc82210273b3#code) |
| MIM | [0x976e33B07565b0c05B08b2e13AfFD3113e3D178d](https://testnet.ftmscan.com/address/0x976e33B07565b0c05B08b2e13AfFD3113e3D178d#code) |
| BaseV1Factory | [0xace5dB14f89D49Aa612bD62caf98f71A5916f9E4](https://testnet.ftmscan.com/address/0xace5dB14f89D49Aa612bD62caf98f71A5916f9E4#code) |
| BaseV1Router01 | [0x55974E7Ed4A95728d24aF056aEA2847F3E79c5f5](https://testnet.ftmscan.com/address/0x55974E7Ed4A95728d24aF056aEA2847F3E79c5f5#code) |
| BaseV1 | [0xc30EB4dD0187AaD1428b998B251aa7d124783905](https://testnet.ftmscan.com/address/0xc30EB4dD0187AaD1428b998B251aa7d124783905#code) |
| tokenizer | [0x3092326DB3220b5102A2999e8A5e80cd7503E1b5](https://testnet.ftmscan.com/address/0x3092326DB3220b5102A2999e8A5e80cd7503E1b5#code) |
| ve3 | [0xeEe7131B79DF27C7dD61DFaEc66474C3A949cDe5](https://testnet.ftmscan.com/address/0xeEe7131B79DF27C7dD61DFaEc66474C3A949cDe5#code) |
| ve3-dist | [0x6d8A9761DCD425912cfb3285AEF2Bde4eb8B416c](https://testnet.ftmscan.com/address/0x6d8A9761DCD425912cfb3285AEF2Bde4eb8B416c#code) |
| BaseV1GaugesFactory | [0x1d601AccbACB22CFA76831eb0ea68A27A39386CC](https://testnet.ftmscan.com/address/0x1d601AccbACB22CFA76831eb0ea68A27A39386CC#code) ||
| BaseV1GaugesVoter | [0xe6E56E917A628232B3cbd78A66e0FC78d480CA12](https://testnet.ftmscan.com/address/0xe6E56E917A628232B3cbd78A66e0FC78d480CA12#code) |
| BaseV1Minter | [0x7d252ecB5f77D8a5bb8010Cb9C22725B8a99d4B1](https://testnet.ftmscan.com/address/0x7d252ecB5f77D8a5bb8010Cb9C22725B8a99d4B1#code) |
