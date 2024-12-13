import { viem } from 'hardhat'
import { formatEther, parseEther, parseUnits, zeroAddress } from 'viem'
import { exec, readJson } from '../utils'

exec(async chainId => {
  const contracts = await readJson(`./ignition/deployments/chain-${chainId}/deployed_addresses.json`)
  const parameters = await readJson(`./ignition/parameters/chain-${chainId}.json`)

  const BetManager = await viem.getContractAt('BetManager', contracts['BetManager#BetManager'])
  const BetConfigurator = await viem.getContractAt('BetConfigurator', contracts['BetConfigurator#BetConfigurator'])
  const GovTokenStaking = await viem.getContractAt('GovTokenStaking', contracts['GovTokenStaking#GovTokenStaking'])

  const publicClient = await viem.getPublicClient()
  const [owner] = await viem.getWalletClients()

  const ethBalance = await publicClient.getBalance({ address: owner.account.address })

  let hash
  hash = await BetManager.write.setCreationFee([parameters.ContractSetup.creationFee])
  await publicClient.waitForTransactionReceipt({ hash })

  hash = await BetConfigurator.write.setOriginAllowlist([parameters.ContractSetup.originAllowlist])
  await publicClient.waitForTransactionReceipt({ hash })

  if (parameters.ContractSetup.chipTokenAllowlist.length) {
    hash = await BetConfigurator.write.setChipTokenAllowlist([parameters.ContractSetup.chipTokenAllowlist])
    await publicClient.waitForTransactionReceipt({ hash })
  }

  // hash = await BetConfigurator.write.setMinWageredTotalAmount([zeroAddress, parseEther('0.1')])
  // await publicClient.waitForTransactionReceipt({ hash })

  // hash = await BetConfigurator.write.setVerificationRatio([
  //   '0x79a02482a880bce3f13e09da970dc34db4cd24d1', // USDC.e
  //   parseUnits('100', 18) / parseUnits('1', 6),
  // ])
  // await publicClient.waitForTransactionReceipt({ hash })

  // hash = await GovTokenStaking.write.setRewardTokens([parameters.GovTokenStaking.rewardTokens])
  // await publicClient.waitForTransactionReceipt({ hash })

  console.log('Gas used:', formatEther(
    ethBalance - (await publicClient.getBalance({ address: owner.account.address }))
  ))

  console.log('The contract setup has been completed.')
})
