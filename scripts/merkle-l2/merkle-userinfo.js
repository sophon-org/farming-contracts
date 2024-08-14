const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { Web3 }= require('web3');


// Assume this data comes from your Solidity contract
// TODO
const userInfos = [
    { account: '0x0000000000000000000000000000000000000001', pid: 0, amount: BigInt(1000), boostAmount: BigInt(100), depositAmount: BigInt(900), rewardSettled: BigInt(500), rewardDebt: BigInt(200) },
    { account: '0x0000000000000000000000000000000000000002', pid: 0, amount: BigInt(2000), boostAmount: BigInt(200), depositAmount: BigInt(1800), rewardSettled: BigInt(1000), rewardDebt: BigInt(400) },
    { account: '0xe749b7469A9911E451600CB31B5Ca180743183cE', pid: 0, amount: BigInt(1879452157034848486000000), boostAmount: BigInt(0), depositAmount: BigInt(1879452157034848486000000), rewardSettled: BigInt(0), rewardDebt: BigInt(0) },
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
const leaves = userInfos.map(userInfo => Buffer.from(hashUserInfo(userInfo).slice(2), 'hex'));


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


// console.log(JSON.stringify(leaves))
const proofs = merkleTree.getProofs()

console.log(JSON.stringify(merkleTree.getHexProofs()))

// Logging all proofs
proofs.forEach((proof, index) => {
    console.log("info", userInfos[index]);
    console.log(`Proof for leaf ${index + 1}:`, proof.map(x => x.data.toString('hex')));
});
// // Verify the proofs
// leaves.forEach((leaf, index) => {
//     const proof = proofs[index];
//     const root = merkleTree.getRoot();
//     const isValid = merkleTree.verify(proof, leaf, root);
//     console.log(`Proof for leaf ${index + 1} is ${isValid ? 'valid' : 'invalid'}`);
// });
