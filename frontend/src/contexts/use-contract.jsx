import { useMemo } from "react"
import { Contract } from "@ethersproject/contracts"
import { useWallet } from "./use-wallet"
import { defaultProvider } from "../utils/constant"

export const useContract = (contractId, abi) => {
  const { provider, selectedAccount, chainId } = useWallet()

  return useMemo(() => {
    let signerOrProvider = selectedAccount ? provider?.getSigner() : provider

    if (chainId && parseInt(chainId, 16) !== 7701) { // TODO change to appropriate network
      signerOrProvider = defaultProvider
    }

    return new Contract(contractId, abi, signerOrProvider || defaultProvider)
  }, [abi, chainId, contractId, provider, selectedAccount])
}
