const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { Web3 }= require('web3');


// Assume this data comes from your Solidity contract
// TODO
const userInfos = [
    { account: '0x0000000000000000000000000000000000000001', pid: 0, amount: '1000', boostAmount: '100', depositAmount: '900', rewardSettled: '500', rewardDebt: '200' },
    { account: '0x0000000000000000000000000000000000000002', pid: 0, amount: '2000', boostAmount: '200', depositAmount: '1800', rewardSettled: '1000', rewardDebt: '400' },
    { account: '0xe749b7469A9911E451600CB31B5Ca180743183cE', pid: 0, amount: '1879452157034848486000000', boostAmount: '0', depositAmount: '1879452157034848486000000', rewardSettled: '0', rewardDebt: '0' },
    // Add more user info as needed
];

function hashUserInfo(userInfo) {
    return Web3.utils.soliditySha3(
        { t: 'address', v: userInfo.account },
        { t: 'uint256', v: userInfo.pid },
        { t: 'uint256', v: userInfo.amount.toString() },
        { t: 'uint256', v: userInfo.boostAmount.toString() },
        { t: 'uint256', v: userInfo.depositAmount.toString() },
        { t: 'uint256', v: userInfo.rewardSettled.toString() },
        { t: 'uint256', v: userInfo.rewardDebt.toString() }
    );
}
// Create leaves by hashing each user's information
const leaves = userInfos.map(userInfo => hashUserInfo(userInfo).slice(2));


// // Create an array of hashes
// const leaves = userInfos.map(info => {
//     return Web3.utils.soliditySha3(
//         { type: 'address', value: info.address },
//         { type: 'uint256', value: info.pid },
//         { type: 'uint256', value: info.amount },
//         { type: 'uint256', value: info.boostAmount },
//         { type: 'uint256', value: info.depositAmount },
//         { type: 'uint256', value: info.rewardSettled },
//         { type: 'uint256', value: info.rewardDebt }
//     );
// });

// Create the Merkle tree
const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });

// Get the root of the tree
const root = merkleTree.getRoot().toString('hex');
console.log('Merkle Root:', root);
console.log('leaves', leaves)

// console.log(JSON.stringify(leaves))

// console.log(JSON.stringify(proofs))
// console.log(JSON.stringify(merkleTree.getHexProofs()))

// // Logging all proofs
// proofs.forEach((proof, index) => {
//     // console.log("info", userInfos[index]);
//     console.log(`Proof for leaf ${index + 1}:`, proof.map(x => x.data.toString('hex')));
// });
// // Verify the proofs
leaves.forEach((leaf, index) => {
    const proof = merkleTree.getProof(leaf)
    console.log("leaf", leaf)
    console.log("p", proof.map(x => x.data.toString('hex')))
});
console.log("asdf")
console.log(merkleTree.toString())


a = Web3.utils.soliditySha3(
    { t: 'address', v: userInfos[2].account },
    { t: 'uint256', v: userInfos[2].pid },
    { t: 'uint256', v: '1879452157034848486000000' },
    // { t: 'uint256', v: userInfos[2].boostAmount.toString() },
    // { t: 'uint256', v: userInfos[2].depositAmount.toString() }
)

console.log("a", a)