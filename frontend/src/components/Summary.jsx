
import { useEffect, useState } from "react"
import { formatUnits, parseUnits } from "@ethersproject/units"

import { useAppContext } from "../contexts/AppContext";
import { numberWithCommas } from "../utils/number-with-commas"
import styles from "./Summary.module.scss"

const currentTimestamp = (Date.now() / 1000).toFixed(0)
const SECONDS_IN_DAY = 86400
export const Summary = () => {
  const { quid, sdai, addressQD } =  useAppContext();
  const [ smartContractStartTimestamp,
    setSmartContractStartTimestamp
  ] = useState("") 
  const [mintPeriodDays, setMintPeriodDays] = useState("")
  const [totalDeposited, setTotalDeposited] = useState("")
  const [totalMinted, setTotalMinted] = useState("")
  const [price, setPrice] = useState("")
  useEffect(() => {
    quid.methods.LENT().call().then(data => {
      setMintPeriodDays(String(data.toNumber() / SECONDS_IN_DAY))
    })
    quid.methods.sale_start().call().then(data => {
      setSmartContractStartTimestamp(data.toString())
    })
    const updateInfo = () => {
      const qdAmount = parseUnits("1", 18)
      quid.methods.qd_amt_to_sdai_amt(qdAmount, currentTimestamp).call().then(data => {
        let n = Number(formatUnits(data, 18)) * 100 // TODO wtf
        if (n > 100) { n = 100 } setPrice(String(n))
      })
      quid.methods.get_total_supply().call().then(totalSupply => {
        setTotalMinted(formatUnits(totalSupply, 18).split(".")[0])
      })
      sdai.methods.balanceOf(addressQD).call()
        .then(data => {
          setTotalDeposited(formatUnits(data, 18))
        })
    }
    const timerId = setInterval(updateInfo, 5000)

    updateInfo()

    return () => clearInterval(timerId)
  }, [quid, sdai])

  const daysLeft = smartContractStartTimestamp ? (
    Math.max(
      Math.ceil(
        Number(mintPeriodDays) -
          (Number(currentTimestamp) - Number(smartContractStartTimestamp)) /
            SECONDS_IN_DAY
      ),
      0
    )
  ) : (
    <>&nbsp;</>
  )
  return (
    <div className={styles.root}>
      <div className={styles.section}>
        <div className={styles.title}>Days left</div>
        <div className={styles.value}>{daysLeft}</div>
      </div>
      <div className={styles.section}>
        <div className={styles.title}>Current price</div>
        <div className={styles.value}>
          <span className={styles.value}>{Number(price).toFixed(0)}</span>
          <span className={styles.cents}> Cents</span>
        </div>
      </div>
      <div className={styles.section}>
        <div className={styles.title}>sDAI Deposited</div>
        <div className={styles.value}>
          ${numberWithCommas(
            parseFloat(String(Number(totalDeposited))).toFixed()
          )}
        </div>
      </div>
      <div className={styles.section}>
        <div className={styles.title}>Minted QD</div>
        <div className={styles.value}>
          {numberWithCommas(Number(totalMinted))}
        </div>
      </div>
    </div>
  )
}
