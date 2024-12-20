import { viem } from 'hardhat'
import { parseEther, parseUnits } from 'viem'
import { exec, getLocalWalletClient, readJson } from '../utils'
import type { Address, Hash } from 'viem'

const betAddress = process.env.LOAD_TEST_BET_ADDRESS as Address
const count = 2000

exec(async chainId => {
  const contracts = await readJson(`./ignition/deployments/chain-${chainId}/deployed_addresses.json`)

  const GovToken = await viem.getContractAt('GovToken', contracts['GovToken#GovToken'])
  const GovTokenStaking = await viem.getContractAt('GovTokenStaking', contracts['GovTokenStaking#GovTokenStaking'])
  const VotingEscrow = await viem.getContractAt('VotingEscrow', contracts['VotingEscrow#VotingEscrow'])

  const { keys } = (await readJson('./keys.json')) as { keys: { adr: Address, key: Hash }[] }
  const Bet = await viem.getContractAt('Bet', betAddress)
  const options = await Bet.read.options() as Address[]
  options.push(Bet.address)
  const optionLength = options.length
  const amountPerTransaction = parseUnits('100', 18)

  const publicClient = await viem.getPublicClient()
  const [owner] = await viem.getWalletClients()

  for (let i = 0; i < count; i++) {
    const address = keys[i].adr
    const privateKey = keys[i].key
    const walletClient = await getLocalWalletClient(privateKey)

    let hash
    hash = await owner.sendTransaction({ to: address, value: parseEther('0.001') })
    await publicClient.waitForTransactionReceipt({ hash })
    hash = await GovToken.write.transfer([address, amountPerTransaction], { account: owner.account })
    await publicClient.waitForTransactionReceipt({ hash })
    hash = await GovToken.write.approve([GovTokenStaking.address, amountPerTransaction], { account: walletClient.account })
    await publicClient.waitForTransactionReceipt({ hash })
    hash = await GovTokenStaking.write.stake([2, amountPerTransaction], { account: walletClient.account })
    await publicClient.waitForTransactionReceipt({ hash })
    const index = Math.floor(Math.random() * optionLength)
    hash = await VotingEscrow.write.transfer([options[index], 1n], { account: walletClient.account })
    await publicClient.waitForTransactionReceipt({ hash })
    const transaction = await publicClient.getTransactionReceipt({ hash })
    console.log(`Gas: ${transaction.gasUsed}`)
    console.log(`${i + 1} Transactions have been sent.`)
  }

  console.log('The test has been completed.')
})
