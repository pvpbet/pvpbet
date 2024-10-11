import { viem } from 'hardhat'
import { parseEther, parseUnits } from 'viem'
import { exec, getLocalWalletClient, readJson } from '../utils'
import type { Address, Hash } from 'viem'

const network = process.env.HARDHAT_NETWORK as string
const betAddress = process.env.LOAD_TEST_BET_ADDRESS as Address
const count = 2000

exec(async () => {
  const networks = await readJson('./networks.json')
  const chainId = networks[network].id
  const parameters = await readJson(`./ignition/parameters/chain-${chainId}.json`)

  const USDC = await viem.getContractAt('USDC', parameters.BetChip.token)
  const BetChip = await viem.getContractAt('BetChip', parameters.BetChip.chip)

  const { keys } = (await readJson('./keys.json')) as { keys: { adr: Address, key: Hash }[] }
  const Bet = await viem.getContractAt('Bet', betAddress)
  const options = await Bet.read.options()
  const optionLength = options.length
  const amountPerTransaction = parseUnits('100', 6)
  const totalAmount = BigInt(count) * amountPerTransaction

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
    const index = Math.floor(Math.random() * optionLength)
    hash = await BetChip.write.transfer([options[index], amountPerTransaction], { account: walletClient.account })
    const transaction = await publicClient.getTransactionReceipt({ hash })
    console.log(`Gas: ${transaction.gasUsed}`)
    console.log(`${i + 1} Transactions have been sent.`)
  }

  console.log('The test has been completed.')
})
