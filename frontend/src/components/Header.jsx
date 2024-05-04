import { Icon } from "./Icon"
import styles from "./Header.module.scss"
import { formatUnits } from "@ethersproject/units"
import { useContext, useEffect, useState } from "react"

import { shortedHash } from "../utils/shorted-hash"
import { numberWithCommas } from "../utils/number-with-commas"

import { useWallet } from "../contexts/use-wallet"
import { useSdaiContract, useQuidContract } from "../utils/constant"
import { NotificationContext } from "../contexts/NotificationProvider"

export const Header = ({ userInfo }) => {
  const { notify } = useContext(NotificationContext)
  const { selectedAccount, connect } = useWallet()
  const sdaiContract = useSdaiContract()
  const quidContract = useQuidContract()
  const [balance, setBalance] = useState("")

  useEffect(() => {
    quidContract.on("Mint", () => {
      sdaiContract?.balanceOf(selectedAccount).then(data => {
        // setBalance(formatUnits(data, 8))
        setBalance(formatUnits(data, 18))
      })
    })
  }, [quidContract, selectedAccount, sdaiContract])

  useEffect(() => {
    const updateBalance = () =>
      sdaiContract?.balanceOf(selectedAccount).then(data => {
        // setBalance(formatUnits(data, 8))
        setBalance(formatUnits(data, 18))
      })
    if (selectedAccount) {
      updateBalance()
    }

    quidContract.on("Mint", updateBalance)
  }, [sdaiContract, selectedAccount, quidContract])

  const handleWalletConnect = async () => {
    try {
      if (!window.ethereum?.isMetaMask) {
        notify({
          severity: "error",
          message: "Metamask is not installed!",
          autoHideDuration: 5500
        })

        return
      }

      await connect()
      notify({
        severity: "success",
        message: "Your wallet successfully connected",
        autoHideDuration: 5000
      })
    } catch (err) {
      const error = err

      if (error.code === 4001) {
        notify({ message: error.message, autoHideDuration: 6000 })
      }
    }
  }

  const summary = (
    <div className={styles.summary}>
      <div className={styles.summaryEl}>
        <div className={styles.summaryElTitle}>Deposited</div>
        <div className={styles.summaryElValue}>
          ${numberWithCommas(userInfo?.costInUsd.toFixed() || "0")}
        </div>
      </div>
      <div className={styles.summaryEl}>
        <div className={styles.summaryElTitle}>My Future QD</div>
        <div className={styles.summaryElValue}>
          {numberWithCommas(userInfo?.qdAmount.toFixed() || "0")}
        </div>
      </div>
      <div className={styles.summaryEl}>
        <div className={styles.summaryElTitle}>Gains</div>
        <div className={styles.summaryElValue}>
          {userInfo?.qdAmount &&
            userInfo?.costInUsd &&
            numberWithCommas(
              `$${(
                Number(userInfo.qdAmount) - Number(userInfo.costInUsd)
              ).toFixed()}`,
            )}
        </div>
      </div>
    </div>
  )

  const balanceBlock = (
    <div className={styles.summaryEl}>
      <div className={styles.summaryElTitle}>cNOTE balance</div>
      <div className={styles.summaryElValue}>
        ${numberWithCommas(parseInt(balance))}
      </div>
    </div>
  )

  return (
    <header className={styles.root}>
      <div className={styles.logoContainer}>
        <a className={styles.logo} href="/"/>
      </div>
      {userInfo && summary}
      <div className={styles.walletContainer}>
        {userInfo && balanceBlock}
        {selectedAccount ? (
          <div className={styles.wallet}>
            <div className={styles.metamaskIcon}>
              <img
                width="18"
                height="18"
                src="/images/metamask.svg"
                alt="metamask"
              />
            </div>
            {shortedHash(selectedAccount)}
            <Icon name="btn-bg" className={styles.walletBackground} />
          </div>
        ) : (
          <button className={styles.wallet} onClick={handleWalletConnect}>
            Connect Metamask
            <Icon name="btn-bg" className={styles.walletBackground} />
          </button>
        )}
      </div>
    </header>
  )
}
