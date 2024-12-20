import { viem } from 'hardhat'
import { parseEther } from 'viem'
import { exec, getLocalWalletClient, readJson } from '../utils'
import type { Address, Hash } from 'viem'

const betAddress = process.env.LOAD_TEST_BET_ADDRESS as Address
const count = 2000

exec(async () => {
  const { keys } = (await readJson('./keys.json')) as { keys: { adr: Address, key: Hash }[] }
  const Bet = await viem.getContractAt('Bet', betAddress)
  const options = await Bet.read.options()
  const optionLength = options.length
  const amountPerTransaction = parseEther('0.1')

  const publicClient = await viem.getPublicClient()
  const [owner] = await viem.getWalletClients()

  for (let i = 0; i < count; i++) {
    const address = keys[i].adr
    const privateKey = keys[i].key
    const walletClient = await getLocalWalletClient(privateKey)

    let hash
    hash = await owner.sendTransaction({ to: address, value: amountPerTransaction * 11n / 10n })
    await publicClient.waitForTransactionReceipt({ hash })
    const index = Math.floor(Math.random() * optionLength)
    hash = await walletClient.sendTransaction({ to: options[index], value: amountPerTransaction })
    await publicClient.waitForTransactionReceipt({ hash })
    const transaction = await publicClient.getTransactionReceipt({ hash })
    console.log(`Gas: ${transaction.gasUsed}`)
    console.log(`${i + 1} Transactions have been sent.`)
  }

  console.log('The test has been completed.')
})
