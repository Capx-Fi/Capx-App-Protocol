async function handle(event) {
    // Sample Event Object.
    // event = {
    //     address: '0xDB336B6d6705736C68D73390437766F7c3beadF5',
    //     blockNumber: 33351919,
    //     transactionHash: '0x22cfd97ad3c0fe8e6e99715b510765954f18b3af5c46d03b3f8d466bab9cfcf5',
    //     transactionIndex: 8,
    //     blockHash: '0xbdcf16bf5ac981cfde2c0390187110f0e0cfb22af9bd71d691edac08d2b21520',
    //     logIndex: 17,
    //     removed: false,
    //     id: 'log_94abdb5f',
    //     returnValues: {
    //       '0': '0x6c368Bd8CC280a54Ad443583D0BC18E4036A2f41',
    //       '1': '0x630216e20e31B4ecf0ccb6C57B8980C0dd02a603',
    //       '2': 'a950643f7e9fabed8a9be1f3befcbb3a_1',
    //       '3': 'iou',
    //       '4': '0xc62E90d28A48479f1b4414f79F557a784E6486f2',
    //       '5': '1679327580',
    //       '6': '1679329465',
    //       '7': '10',
    //       '8': '100000000000000000',
    //       creator: '0x6c368Bd8CC280a54Ad443583D0BC18E4036A2f41',
    //       questAddress: '0x630216e20e31B4ecf0ccb6C57B8980C0dd02a603',
    //       questId: 'a950643f7e9fabed8a9be1f3befcbb3a_1',
    //       questRewardType: 'iou',
    //       rewardToken: '0xc62E90d28A48479f1b4414f79F557a784E6486f2',
    //       startTime: '1679327580',
    //       endTime: '1679329465',
    //       maxParticipants: '10',
    //       rewardAmountInWei: '100000000000000000'
    //     },
    //     event: 'CapxQuestCreated',
    //     signature: '0x001a3ce35a09277508eb505dc0e1936741e6fea9c69b5ae25365b90a5ed682ef',
    //     raw: {
    //       data: '0x00000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000140000000000000000000000000c62e90d28a48479f1b4414f79f557a784e6486f2000000000000000000000000000000000000000000000000000000006418815c00000000000000000000000000000000000000000000000000000000641888b9000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000016345785d8a0000000000000000000000000000000000000000000000000000000000000000002261393530363433663765396661626564386139626531663362656663626233615f310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003696f750000000000000000000000000000000000000000000000000000000000',
    //       topics: [
    //         '0x001a3ce35a09277508eb505dc0e1936741e6fea9c69b5ae25365b90a5ed682ef',
    //         '0x0000000000000000000000006c368bd8cc280a54ad443583d0bc18e4036a2f41',
    //         '0x000000000000000000000000630216e20e31b4ecf0ccb6c57b8980c0dd02a603'
    //       ]
    //     }
    // };

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