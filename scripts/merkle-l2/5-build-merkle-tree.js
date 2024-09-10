const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { Web3 }= require('web3');
const fs = require('fs');


function hashUserInfo(userInfo) {
    return Web3.utils.soliditySha3(
        { t: 'address', v: userInfo.user }, // address
        { t: 'uint256', v: userInfo.pid }, // pid
        { t: 'uint256', v: userInfo.userInfo.amount }, // amount
        { t: 'uint256', v: userInfo.userInfo.boostAmount }, // boostAmount
        { t: 'uint256', v: userInfo.userInfo.depositAmount }, // depositAmount
        { t: 'uint256', v: userInfo.userInfo.rewardSettled }, // rewardSettled
        { t: 'uint256', v: userInfo.userInfo.rewardDebt } // rewardDebt
    );
}


fs.readFile('./scripts/merkle-l2/output/3-update-user-info.json', 'utf8', (err, data) => {
    if (err) {
        console.error('Error reading file:', err);
        return;
    }

    try {

        const jsonData = JSON.parse(data);

        const leaves = jsonData.users.map(userInfo => hashUserInfo(userInfo).slice(2));

        const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
        const root = merkleTree.getRoot().toString('hex');
        console.log('Merkle Root:', root);
        
        claims = {}
        totalDepositAmount = {}
        
        leaves.forEach((leaf, index) => {
            proof = merkleTree.getProof(leaf).map(x => x.data.toString('hex'))
            
            // console.log('proof:', proof);
            userInfo = jsonData.users[index]
            claims[userInfo.user] = {
                index: index,
                user: userInfo.user,
                pid: userInfo.pid,
                amount: userInfo.userInfo.amount,
                boostAmount: userInfo.userInfo.boostAmount,
                depositAmount: userInfo.userInfo.depositAmount,
                rewardSettled: userInfo.userInfo.rewardSettled,
                rewardDebt: userInfo.userInfo.rewardDebt,
                proof: proof
            }
        });
        
        // console.log(totalDepositAmount);
        data = {
            merkleRoot: root,
            totalDepositAmount: totalDepositAmount,
            claims,
        }

        filename = "./scripts/merkle-l2/output/5-proof.json"
        const jsonString = JSON.stringify(data, null, 4);
        fs.writeFile(filename, jsonString, (err) => {
            if (err) {
                console.error('Error writing to file', err);
            } else {
                console.log('Successfully wrote JSON to file');
            }
        });

    } catch (parseError) {
        console.error('Error parsing JSON:', parseError);
    }
});


// 1 preprocess handle BEAM_LP, calculate ratios
// 2 add to users depending on the ratios