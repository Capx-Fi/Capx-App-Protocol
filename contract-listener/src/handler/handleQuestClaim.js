const getTxByHash = require("../apis/getTxByHash.js");
const makeClaim = require("../apis/makeClaim.js");

const { ALCHEMY_ENDPOINTS } = require("../constants/constants.js");

async function handle(env, network, event) {
    try {
        event = {
            address: '0xDB336B6d6705736C68D73390437766F7c3beadF5',
            blockNumber: 33351964,
            transactionHash: '0xe4c0af22173f19ac62bb896307acfa675b7552212ef414675dd00aa36908bb63',
            transactionIndex: 10,
            blockHash: '0x13cf11e288900b87faf5b87dbededc84e03a28e511701f65e910c7eda8e18eb2',
            logIndex: 15,
            removed: false,
            id: 'log_5d4edfad',
            returnValues: {
            '0': '0x630216e20e31B4ecf0ccb6C57B8980C0dd02a603',
            '1': 'a950643f7e9fabed8a9be1f3befcbb3a_1',
            '2': '0xdea1d0816d88B72F522991B5AB955ca808Dde18D',
            '3': '0xc62E90d28A48479f1b4414f79F557a784E6486f2',
            '4': '100000000000000000',
            questAddress: '0x630216e20e31B4ecf0ccb6C57B8980C0dd02a603',
            questId: 'a950643f7e9fabed8a9be1f3befcbb3a_1',
            claimer: '0xdea1d0816d88B72F522991B5AB955ca808Dde18D',
            rewardToken: '0xc62E90d28A48479f1b4414f79F557a784E6486f2',
            rewardAmount: '100000000000000000'
            },
            event: 'CapxQuestRewardClaimed',
            signature: '0x1f316933ef3d09c0e19c6de2b7017efaab425806453d954a28f021c550029e35',
            raw: {
            data: '0x0000000000000000000000000000000000000000000000000000000000000080000000000000000000000000dea1d0816d88b72f522991b5ab955ca808dde18d000000000000000000000000c62e90d28a48479f1b4414f79f557a784e6486f2000000000000000000000000000000000000000000000000016345785d8a0000000000000000000000000000000000000000000000000000000000000000002261393530363433663765396661626564386139626531663362656663626233615f31000000000000000000000000000000000000000000000000000000000000',
            topics: [
                '0x1f316933ef3d09c0e19c6de2b7017efaab425806453d954a28f021c550029e35',
                '0x000000000000000000000000630216e20e31b4ecf0ccb6c57b8980c0dd02a603'
            ]
            }
        };

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

        txInputs = await getTxByHash.get(txHash, RPC_URL, txInputs);
        if (!txInputs?.hash) {
            const try2Url = RPC_URLS[Math.floor(Math.random() * RPC_URLS.length)];
            txInputs = await getTxByHash.get(txHash, try2Url, txInputs);
            if (!txInputs?.hash) {
                const try3Url = RPC_URLS[Math.floor(Math.random() * RPC_URLS.length)];
                txInputs = await getTxByHash.get(txHash, try3Url, txInputs);
            }
        }

        const returnObj = {
            address: address,
            transaction: {
                txHash: txHash,
                txTimestamp: txTimestamp,
                txInputs: txInputs,
                txRewardToken: txRewardToken,
                txRewardAmt: txRewardAmt
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

handle("TESTNET", "POLYGON", "");

module.exports.handle = handle;