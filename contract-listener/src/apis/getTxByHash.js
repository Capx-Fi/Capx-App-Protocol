const axios = require('axios');
const decoder = require("abi-decoder");

async function get(
    txHash,
    rpcUrl,
    txInputs
) {
    try {
        console.log(`Extracting Details for Tx : ${txHash}`);
        const txData = await axios.post(
            rpcUrl,
            {
                jsonrpc: "2.0",
                method: "eth_getTransactionByHash",
                params: [txHash],
                id: 1
            }
        );
        
        decoder.addABI([{"inputs":[{"internalType":"bytes32","name":"_messageHash","type":"bytes32"},{"internalType":"bytes","name":"_signature","type":"bytes"},{"internalType":"string","name":"_questId","type":"string"}],"name":"claim","outputs":[],"stateMutability":"nonpayable","type":"function"}]);
        const decodedData = decoder.decodeMethod(txData?.data?.result?.input);
        if (decodedData?.name) {
            const params = decodedData.params;
            params.forEach((param) => {
                if(param.name === "_messageHash") {
                    txInputs[`hash`] = param.value;
                } else if (param.name === "_signature") {
                    txInputs[`signature`] = param.value;
                }
            });

            return txInputs;
        }
    } catch (err) {
        console.log(`Axios API Error: ${rpcUrl}`, err.message);
    }
    return txInputs;
}

module.exports.get = get;