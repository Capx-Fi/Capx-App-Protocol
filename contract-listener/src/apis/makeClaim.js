const axios = require('axios');
const { CLAIM } = require("../constants/constants.js");

async function claim(
    data
) {
    try {
        const payload = JSON.stringify({"data": data});
        await axios.post(
            CLAIM.URL,
            payload,
            {
                headers: {
                    'Authorization': "Bearer " + CLAIM.TOKEN,
                    'Content-Type': 'application/json'
                },
            }
        );
    } catch (err) {
        console.log(`Axios API Error: ${CLAIM.URL}`, err.message);
    }
}

module.exports.claim = claim;