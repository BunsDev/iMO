import { Icon } from "./Icon"
import styles from "./Header.module.scss"
import { formatUnits } from "@ethersproject/units"
import { useContext, useEffect, useState } from "react"

import { shortedHash } from "../utils/shorted-hash"
import { numberWithCommas } from "../utils/number-with-commas"
import { useAppContext } from "../contexts/AppContext";
import { NotificationContext } from "../contexts/NotificationProvider"

export const Header = ({ userInfo }) => {
  const { notify } = useContext(NotificationContext)

  const { quid, sdai, account, connectToMetaMask, connected, connecting } =
    useAppContext();

  const [isLoading, setIsLoading] = useState("idle");

  const [balance, setBalance] = useState("")



  // TODO
  useEffect(() => {
    if (connected) {
      // getNumber();  
    }
  }, [connected]);
  // TOOD do .on("Minted")


  // TODO
  // useEffect(() => {
  //   quidContract.on("Minted", () => {
  //     sdaiContract?.balanceOf(account).then(data => {
  //       // setBalance(formatUnits(data, 8))
  //       setBalance(formatUnits(data, 18))
  //     })
  //   })
  // }, [quidContract, account, sdaiContract])

  // useEffect(() => {
  //   const updateBalance = () =>
  //     sdaiContract?.balanceOf(account).then(data => {
  //       // setBalance(formatUnits(data, 8))
  //       setBalance(formatUnits(data, 18))
  //     })
  //   if (account) {
  //     updateBalance()
  //   }

  //   quidContract.on("Minted", updateBalance)
  // }, [sdaiContract, account, quidContract])

  // notify({
  //   severity: "success",
  //   message: "Your wallet successfully connected",
  //   autoHideDuration: 5000
  // })


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
      <div className={styles.summaryElTitle}>sDAI balance</div>
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
        <div className={styles.wallet}>
          {!connected && (
            <button className={styles.wallet} onClick={connectToMetaMask}>
              {connecting ? "Connecting..." : "Connect to MetaMask"}
            </button>
          )}
          {connected && (
            shortedHash(account)
          )}
          <Icon name="btn-bg" className={styles.walletBackground} />
         </div>
      </div>
    </header>
  )
}
