const { ALCHEMY_ENDPOINTS, CONTRACTS } = require("./constants/constants.js");
const { createAlchemyWeb3 } = require("@alch/alchemy-web3");
const questClaim = require("./handler/handleQuestClaim.js");
const questCreation = require("./handler/handleQuestCreation.js");

const ENV = "TESTNET";
const NETWORK = "POLYGON";

const web3 = createAlchemyWeb3(
    ALCHEMY_ENDPOINTS[`${ENV}`][`${NETWORK}`][`WSS`],
    {
        maxRetries: 1000,
        retryInterval: 5000,
        retryJitter: 200
    }
);

const CAPX_QUEST_FORGER = CONTRACTS[`${ENV}`][`${NETWORK}`][`CAPX_QUEST_FORGER`];

const CapxQuestForger = new web3.eth.Contract(
    JSON.parse(CAPX_QUEST_FORGER.ABI),
    CAPX_QUEST_FORGER.ADDRESS
)

async function listenForEvents() {
    CapxQuestForger.events.CapxQuestCreated({
        fromBlock: 33348175,
    }).on("data", async(event) => {
        questCreation.handle(event);
    });

    CapxQuestForger.events.CapxQuestRewardClaimed({
        fromBlock: 33348175,
    }).on("data", async(event) => {
        questClaim.handle(ENV, NETWORK, event);
    });
}

listenForEvents();