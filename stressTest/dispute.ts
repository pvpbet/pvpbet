import { viem } from 'hardhat'
import { exec, getLocalWalletClient, readJson } from '../utils'
import type { Address, Hash } from 'viem'

const betAddress = process.env.LOAD_TEST_BET_ADDRESS as Address
const count = 1000

exec(async () => {
  const { keys } = (await readJson('./keys.json')) as { keys: { adr: Address, key: Hash }[] }
  const Bet = await viem.getContractAt('Bet', betAddress)
  const minDisputedTotalAmount = await Bet.read.minDisputedTotalAmount()
  const amountPerTransaction = minDisputedTotalAmount / BigInt(count)

  const [owner] = await viem.getWalletClients()

  for (let i = 0; i < count; i++) {
    const address = keys[i].adr
    const privateKey = keys[i].key
    await owner.sendTransaction({ to: address, value: amountPerTransaction * 11n / 10n })
    const walletClient = await getLocalWalletClient(privateKey)
    await walletClient.sendTransaction({ to: Bet.address, value: amountPerTransaction })
    console.log(`${i + 1} Transactions have been sent.`)
  }

  console.log('The test has been completed.')
})
