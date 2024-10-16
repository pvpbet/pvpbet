import { viem } from 'hardhat'
import { parseEther } from 'viem'
import { exec, getLocalWalletClient, readJson } from '../utils'
import type { Address, Hash } from 'viem'

const betAddress = process.env.LOAD_TEST_BET_ADDRESS as Address
const count = 1000

exec(async chainId => {
  const parameters = await readJson(`./ignition/parameters/chain-${chainId}.json`)

  const USDC = await viem.getContractAt('USDC', parameters.BetChip.token)
  const BetChip = await viem.getContractAt('BetChip', parameters.BetChip.chip)

  const { keys } = (await readJson('./keys.json')) as { keys: { adr: Address, key: Hash }[] }
  const Bet = await viem.getContractAt('Bet', betAddress)
  const totalAmount = await Bet.read.minDisputedTotalAmount()
  const amountPerTransaction = totalAmount / BigInt(count)

  await USDC.write.mint([totalAmount])
  await USDC.write.approve([BetChip.address, totalAmount])
  await BetChip.write.deposit([totalAmount])

  const publicClient = await viem.getPublicClient()
  const [owner] = await viem.getWalletClients()

  for (let i = 0; i < count; i++) {
    const address = keys[i].adr
    const privateKey = keys[i].key
    const walletClient = await getLocalWalletClient(privateKey)

    let hash
    hash = await owner.sendTransaction({ to: address, value: parseEther('0.00025') })
    await publicClient.waitForTransactionReceipt({ hash })
    hash = await BetChip.write.transfer([address, amountPerTransaction])
    await publicClient.waitForTransactionReceipt({ hash })
    hash = await BetChip.write.transfer([Bet.address, amountPerTransaction], { account: walletClient.account })
    await publicClient.waitForTransactionReceipt({ hash })
    const transaction = await publicClient.getTransactionReceipt({ hash })
    console.log(`Gas: ${transaction.gasUsed}`)
    console.log(`${i + 1} Transactions have been sent.`)
  }

  console.log('The test has been completed.')
})
