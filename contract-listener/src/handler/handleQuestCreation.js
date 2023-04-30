async function handle(event) {
    // Sample Event Object.
    
    const questAddress = event.returnValues.questAddress;
    const questId = event.returnValues.questId;
    const questRewardType = event.returnValues.questRewardType;
    const rewardToken = event.returnValues.rewardToken;
    const startTime = event.returnValues.startTime;
    const endTime = event.returnValues.endTime;
    const maxParticipants = event.returnValues.maxParticipants;
    const rewardAmountInWei = event.returnValues.rewardAmountInWei;
}

module.exports.handle = handle;