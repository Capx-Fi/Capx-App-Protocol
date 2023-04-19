const axios = require('axios');
const { CLAIM } = require("../constants/constants.js");

async function claim(
    data
) {
    // Extract Token
    try {
        const payload = JSON.stringify(
            {
                email : `${CLAIM.EMAIL}`,
                password : `${CLAIM.SECRET}`,
                returnSecureToken: true
            }
        );
        const response = await axios.post(
            CLAIM.TOKEN_URL,
            payload,
            {
                headers: {
                    'Content-Type': 'application/json'
                }
            }
        );
        if (response?.data?.idToken) {
            try {
                const payload = JSON.stringify({"data": data});
                console.log("Payload",payload);
                const claimResponse = await axios.post(
                    CLAIM.URL,
                    payload,
                    {
                        headers: {
                            'Authorization': "Bearer " + response?.data?.idToken,
                            'Content-Type': 'application/json'
                        },
                    }
                );
                console.log("Claim Response", claimResponse);
            } catch (err) {
                console.log(`Axios API Claim Error: ${CLAIM.URL}`, err.message);
            }
        }
    } catch (err) {
        console.log(`Axios API Token Error: ${CLAIM.URL}`, err.message);
    }
}

module.exports.claim = claim;