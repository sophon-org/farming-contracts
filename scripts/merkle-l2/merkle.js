const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const { Web3 }= require('web3');


// Assume this data comes from your Solidity contract
// TODO
const userInfos = {
    '0x0000000000000000000000000000000000000001': { amount: 1000, boostAmount: 100, depositAmount: 900, rewardSettled: 500, rewardDebt: 200 },
    '0x0000000000000000000000000000000000000002': { amount: 2000, boostAmount: 200, depositAmount: 1800, rewardSettled: 1000, rewardDebt: 400 },
    // Add more user info as needed
};

// Create an array of hashes
const leaves = Object.entries(userInfos).map(([address, info]) => {
    return Web3.utils.soliditySha3(
        { type: 'address', value: address },
        { type: 'uint256', value: info.amount },
        { type: 'uint256', value: info.boostAmount },
        { type: 'uint256', value: info.depositAmount },
        { type: 'uint256', value: info.rewardSettled },
        { type: 'uint256', value: info.rewardDebt }
    );
});

// Create the Merkle tree
const merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });

// Get the root of the tree
const root = merkleTree.getRoot().toString('hex');
console.log('Merkle Root:', root);

// Generate a proof for a specific user
const leaf = leaves[0]; // Example for the first user
const proof = merkleTree.getProof(leaf).map(x => x.data.toString('hex'));
console.log('Proof for the first user:', proof);
console.log(JSON.stringify(leaves))
