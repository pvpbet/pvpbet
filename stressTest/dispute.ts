import { viem } from 'hardhat'
import { exec, getLocalWalletClient, readJson } from '../utils'
import type { Address, Hash } from 'viem'

const betAddress = process.env.LOAD_TEST_BET_ADDRESS as Address
const count = 1000

exec(async () => {
  const { keys } = (await readJson('./keys.json')) as { keys: { adr: Address, key: Hash }[] }
  const Bet = await viem.getContractAt('Bet', betAddress)
  const totalAmount = await Bet.read.minDisputedTotalAmount()
  const amountPerTransaction = totalAmount / BigInt(count)

  const publicClient = await viem.getPublicClient()
  const [owner] = await viem.getWalletClients()

  for (let i = 0; i < count; i++) {
    const address = keys[i].adr
    const privateKey = keys[i].key
    const walletClient = await getLocalWalletClient(privateKey)

    let hash
    hash = await owner.sendTransaction({ to: address, value: amountPerTransaction * 11n / 10n })
    await publicClient.waitForTransactionReceipt({ hash })
    hash = await walletClient.sendTransaction({ to: Bet.address, value: amountPerTransaction })
    const transaction = await publicClient.getTransactionReceipt({ hash })
    console.log(`Gas: ${transaction.gasUsed}`)
    console.log(`${i + 1} Transactions have been sent.`)
  }

  console.log('The test has been completed.')
})
