# Defi321 is the simplest DeFi

This code is created for study purposes. Please do not use it in a production environment.

It has the following characteristics:

- It does not communicate with Oracle at all and sets the token price as $1,000.
- It does not handle decimals.
- The fee is set at 2%.
- The reward to liquidity providers is given when the accumulated swap fees in the pool exceed $1,000.

# how to intaract

$ truffle console

then

```
const accounts = await web3.eth.getAccounts();
const me = web3.utils.toChecksumAddress(accounts[0]);
const Defi321 = await Defi321.deployed();
const TokenA = await TokenA.deployed();
const TokenB = await TokenB.deployed();
web3.eth.defaultAccount = accounts[0];

const addressAString = TokenA.address;
const addressA = web3.utils.toChecksumAddress(addressAString);
const addressBString = TokenB.address;
const addressB = web3.utils.toChecksumAddress(addressBString);
const defi = web3.utils.toChecksumAddress(Defi321.address);
const result = await Defi321.createPool(addressA, addressB);

await TokenA.approve(defi, 100000);
await TokenB.approve(defi, 100000);
await TokenA.transfer(me, 10000);
await TokenB.transfer(me, 10000);
await Defi321.provideLiquidity(addressA, addressB, 1000, 1000);
await Defi321.withdrawLiquidity(addressA, addressB, 1, 1);
await TokenA.balanceOf(me)
await TokenB.balanceOf(me)
await Defi321.swap(addressA, addressB, 100);
await TokenA.balanceOf(me)
await TokenB.balanceOf(me)

const pairId = await Defi321.getPairId(addressA, addressB);
await Defi321.getCurrentReward();
await Defi321.getPool(pairId);
await Defi321.claim();
```