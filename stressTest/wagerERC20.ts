import { viem } from 'hardhat'
import { parseEther, parseUnits } from 'viem'
import { exec, getLocalWalletClient, readJson } from '../utils'
import type { Address, Hash } from 'viem'

const network = process.env.HARDHAT_NETWORK as string
const betAddress = process.env.LOAD_TEST_BET_ADDRESS as Address
const count = 2000

exec(async () => {
  const contracts = (await readJson('./contracts.json')) as Record<string, Record<string, Address>>
  const USDC = await viem.getContractAt('USDC', contracts[network].USDC)
  const BetChip = await viem.getContractAt('BetChip', contracts[network].BetChip)

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
    let nonce = await publicClient.getTransactionCount({ address: owner.account.address })
    await owner.sendTransaction({ to: address, value: parseEther('0.00007'), nonce })
    nonce++
    await BetChip.write.transfer([address, amountPerTransaction], { nonce })
    const walletClient = await getLocalWalletClient(privateKey)
    await BetChip.write.transfer([options[Math.floor(Math.random() * optionLength)], amountPerTransaction], { account: walletClient.account })
    console.log(`${i + 1} Transactions have been sent.`)
  }

  console.log('The test has been completed.')
})
