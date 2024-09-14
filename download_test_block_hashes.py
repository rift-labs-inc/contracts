import asyncio
import httpx
from dotenv import load_dotenv
import os

load_dotenv()

BITCOIN_RPC = os.getenv('BITCOIN_RPC')
LOOKBACK = 30
CONCURRENT_REQUESTS = 5

async def get_block_count(client):
    response = await client.post(BITCOIN_RPC, json={
        "jsonrpc": "1.0",
        "id": "curltest",
        "method": "getblockcount",
        "params": []
    })
    return response.json()['result']

async def get_block_hash(client, height):
    response = await client.post(BITCOIN_RPC, json={
        "jsonrpc": "1.0",
        "id": "curltest",
        "method": "getblockhash",
        "params": [height]
    })
    return response.json()['result']

async def main():
    async with httpx.AsyncClient() as client:
        current_height = await get_block_count(client)
        print(f"Current block height: {current_height}")

        start_height = current_height - LOOKBACK + 1
        heights = range(start_height, current_height + 1)

        semaphore = asyncio.Semaphore(CONCURRENT_REQUESTS)

        async def fetch_block_hash(height):
            async with semaphore:
                return await get_block_hash(client, height)

        tasks = [fetch_block_hash(height) for height in heights]
        hashes = await asyncio.gather(*tasks)

        print("\nSolidity code snippet:")
        print("bytes32[] public blockHashes = [")
        for hash in hashes:
            print(f"    bytes32(0x{hash}),")
        print("];")

        print("\nuint64[] public blockHeights = [", end="")
        print(", ".join(map(str, heights)), end="")
        print("];")

if __name__ == "__main__":
    asyncio.run(main())
