const getTxByHash = require("../apis/getTxByHash.js");
const makeClaim = require("../apis/makeClaim.js");

const { ALCHEMY_ENDPOINTS } = require("../constants/constants.js");

async function handle(env, network, event) {
    try {
        const questAddress = event.returnValues.questAddress;
        const questId = event.returnValues.questId;
        const address = event.returnValues.claimer;
        const txRewardToken = event.returnValues.rewardToken;
        const txRewardAmt = event.returnValues.rewardAmount;
        const txHash = event.transactionHash;
        const txTimestamp = Math.ceil(new Date().getTime() / 1000);
        let txInputs = {};

        // Pick Transaction.
        const RPC_URLS = ALCHEMY_ENDPOINTS[`${env}`][`${network}`][`HTTPS`];
        const RPC_URL = RPC_URLS[Math.floor(Math.random() * RPC_URLS.length)];

        // txInputs = await getTxByHash.get(txHash, RPC_URL, txInputs);
        // if (!txInputs?.hash) {
        //     const try2Url = RPC_URLS[Math.floor(Math.random() * RPC_URLS.length)];
        //     txInputs = await getTxByHash.get(txHash, try2Url, txInputs);
        //     if (!txInputs?.hash) {
        //         const try3Url = RPC_URLS[Math.floor(Math.random() * RPC_URLS.length)];
        //         txInputs = await getTxByHash.get(txHash, try3Url, txInputs);
        //     }
        // }

        const returnObj = {
            address: address,
            transaction: {
                txHash: txHash,
                txTimestamp: txTimestamp,
                txInputs: txInputs,
                txRewardToken: txRewardToken,
                txTokenAmt: txRewardAmt
            },
            questId: questId,
            questAddress: questAddress,
            rpcUrl: RPC_URL
        };

        await makeClaim.claim(returnObj);
        // Make API Call.
    } catch (err) {
        console.log(err);
    }
}

// handle("TESTNET", "POLYGON", "");

module.exports.handle = handle;