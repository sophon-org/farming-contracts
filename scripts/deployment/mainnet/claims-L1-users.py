from brownie import *
import json
import csv

MC = interface.IMerkleClaimer("0xf4551b26cbB924BFa6117aD7b5D5Da2f70Fe8b9B")

with open("scripts/merkle-l2/TGE/merkletree_1.json") as f1, open("scripts/merkle-l2/TGE/merkletree_2.json") as f2:
    data1 = json.load(f1)
    data2 = json.load(f2)
combined = sorted(data1 + data2, key=lambda x: int(x["merkleIndex"]))

address_to_merkle = {
    entry["address"].lower(): entry["merkleIndex"]
    for entry in combined
}

final_result = []
with open("scripts/merkle-l2/TGE/allocations.csv", "r", encoding="utf-8") as csvfile:
    reader = csv.DictReader(csvfile)
    for row in reader:
        if row["Slug"] != "sophon_farmer":
            continue
        user = row["current_owner"].lower()
        amount = row["SOPH - wei"]
        merkleIndex = address_to_merkle.get(user)
        if merkleIndex is None:
            continue
        if not MC.isClaimed(merkleIndex):
            entry = {
                "user": user,
                "merkleIndex": merkleIndex,
                "amount": amount
            }
            print(entry)
            final_result.append(entry)
        else:
            print("skip", user, merkleIndex, amount)

with open("scripts/merkle-l2/output/final_unclaimed_with_amounts.json", "w", encoding="utf-8") as out:
    json.dump(final_result, out, indent=2)

print("Done")