import json
import time
import json

MC = interface.IMerkleClaimer("0xf4551b26cbB924BFa6117aD7b5D5Da2f70Fe8b9B")


import json


with open("./scripts/merkle-l2/TGE/merkletree_1.json") as f1, open("./scripts/merkle-l2/TGE/merkletree_2.json") as f2:
    data1 = json.load(f1)
    data2 = json.load(f2)
combined = sorted(data1 + data2, key=lambda x: int(x["merkleIndex"]))

address_to_merkle = {
    entry["address"].lower(): entry["merkleIndex"]
    for entry in combined
}

def has_address(addr):
    return addr.lower() in address_to_merkle
def get_merkle_index(addr):
    return address_to_merkle.get(addr.lower())

unclaimed = []

file_path = './scripts/merkle-l2/output/5-proof.json'
with open(file_path, 'r', encoding='utf-8') as file:
    data = json.load(file)
    claims = data.get('claims', {})
 
    for index, user in enumerate(claims, start=1):
        # print(user)
        if has_address(user):
            merkleIndex = get_merkle_index(user)
            isClaimed = MC.isClaimed(merkleIndex)
            if not isClaimed:
                u = {
                    "index": index,
                    "user": user,
                    "merkleIndex": merkleIndex
                }
                print(u)
                unclaimed.append(u)
                
with open('./scripts/merkle-l2/output/unclaimed.json', 'w', encoding='utf-8') as out:
    json.dump(unclaimed, out, indent=2)


with open('./scripts/merkle-l2/output/unclaimed.json', 'r', encoding='utf-8') as f:
    unclaimed = json.load(f)
    
            
allocations = {}
import csv
with open('./scripts/merkle-l2/TGE/allocations.csv', 'r', encoding='utf-8') as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        if row['Slug'] == 'sophon_farmer':
            addr = row['current_owner'].lower()
            allocations[addr] = row['SOPH - wei']


final_result = []
for entry in unclaimed:
    user = entry['user'].lower()
    if user in allocations:
        entry_with_amount = {
            "user": user,
            "merkleIndex": entry["merkleIndex"],
            "amount": allocations[user]
        }
        print(entry_with_amount)
        final_result.append(entry_with_amount)
with open('./scripts/merkle-l2/output/final_unclaimed_with_amounts.json', 'w', encoding='utf-8') as out:
    json.dump(final_result, out, indent=2)

print("Done")