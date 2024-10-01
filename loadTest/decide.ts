import { viem } from 'hardhat'
import { parseEther, parseUnits } from 'viem'
import { exec, getLocalWalletClient, readJson } from '../utils'
import type { Address, Hash } from 'viem'

const betAddress = process.env.LOAD_TEST_BET_ADDRESS as Address
const count = 2000

exec(async () => {
  const contracts = (await readJson('./contracts.json')) as Record<string, Address>
  const GovToken = await viem.getContractAt('GovToken', contracts.GovToken)
  const GovTokenStaking = await viem.getContractAt('GovTokenStaking', contracts.GovTokenStaking)
  const BetVotingEscrow = await viem.getContractAt('BetVotingEscrow', contracts.BetVotingEscrow)

  const { keys } = (await readJson('./keys.json')) as { keys: { adr: Address, key: Hash }[] }
  const Bet = await viem.getContractAt('Bet', betAddress)
  const options = await Bet.read.options()
  const optionLength = options.length

  const [owner] = await viem.getWalletClients()

  const amount = parseUnits('100', 18)
  for (let i = 0; i < count; i++) {
    const address = keys[i].adr
    const privateKey = keys[i].key
    await owner.sendTransaction({ to: address, value: parseEther('0.01') })
    await GovToken.write.transfer([address, amount], { account: owner.account })
    const walletClient = await getLocalWalletClient(privateKey)
    await GovToken.write.approve([GovTokenStaking.address, amount], { account: walletClient.account })
    await GovTokenStaking.write.stake([1, amount], { account: walletClient.account })
    await BetVotingEscrow.write.transfer([options[Math.floor(Math.random() * optionLength)], amount], { account: walletClient.account })
    console.log(`${i + 1} Transactions have been sent.`)
  }

  console.log('The test has been completed.')
})
