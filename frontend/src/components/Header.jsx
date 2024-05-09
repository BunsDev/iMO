import { Icon } from "./Icon"
import styles from "./Header.module.scss"
import { useEffect, useState} from "react"

import { shortedHash } from "../utils/shorted-hash"
import { numberWithCommas } from "../utils/number-with-commas"
import { useAppContext } from "../contexts/AppContext";

export const Header = ({ userInfo }) => {
  const { account, connectToMetaMask, connected, connecting } =
    useAppContext();

  const [actualAmount, setAmount] = useState(0)
  const [actualUsd, setUsd] = useState(0)

  //const [balance, setBalance] = useState("")



  // TODO
  useEffect(() => {
    if (connected) {
      // getNumber();  
      console.warn("USER INFO: ", userInfo)
      
      if(userInfo){
        if (typeof userInfo.costInUsd === "number") setUsd(userInfo.costInUsd.toFixed())
          else setAmount(0)
  
        if (typeof qdAmount === "number") setAmount(userInfo.qdAmount.toFixed())
          else setAmount(0)
      }
    }
  }, [setAmount, setUsd, connected, userInfo]);
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
          ${numberWithCommas(actualUsd)}
        </div>
      </div>
      <div className={styles.summaryEl}>
        <div className={styles.summaryElTitle}>My Future QD</div>
        <div className={styles.summaryElValue}>
          {numberWithCommas(actualAmount)}
        </div>
      </div>
      <div className={styles.summaryEl}>
        <div className={styles.summaryElTitle}>Gains</div>
        <div className={styles.summaryElValue}>
          {userInfo?.qdAmount &&
            userInfo?.costInUsd &&
            numberWithCommas(
              `$${(
                Number(actualAmount) - Number(actualUsd)
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
        ${numberWithCommas(parseInt())}
      </div>
    </div>
  )

  return (
    <header className={styles.root}>
      <div className={styles.logoContainer}>
        <a className={styles.logo} href="/" >
          <span className="visually-hidden">Put here</span>
        </a>
      </div>
      {userInfo && summary}
      <div className={styles.walletContainer}>
        {userInfo && balanceBlock}
        <div className={styles.wallet}>
          {!connected && (
            <button className={styles.walletButton} onClick={connectToMetaMask}>
              {connecting ? "Connecting..." : "Connect to MetaMask"}
            </button>
          )}
          {connected && (
            <span className={styles.accountInfo}>
              {shortedHash(account)}
            </span>
          )}
          <Icon name="btn-bg" className={styles.walletBackground} />
        </div>
      </div>
    </header>
  )
}
