
import { useEffect, useState, useCallback } from "react"
import { formatUnits, parseUnits } from "@ethersproject/units"
import { BigNumber } from "@ethersproject/bignumber"
import { useAppContext } from "../contexts/AppContext";
import { numberWithCommas } from "../utils/number-with-commas"
import styles from "./Summary.module.scss"

const currentTimestamp = (Date.now() / 1000).toFixed(0)
const SECONDS_IN_DAY = 86400

export const Summary = () => {
  const { quid, sdai, addressQD } = useAppContext();

  const [smartContractStartTimestamp, setSmartContractStartTimestamp] = useState("")
  const [mintPeriodDays, setMintPeriodDays] = useState("")
  const [totalDeposited, setTotalDeposited] = useState("")
  const [totalMinted, setTotalMinted] = useState("")
  const [price, setPrice] = useState("")
  const [bigNumber, setBigNumber] = useState(0)

  const updateInfo = useCallback(() => {
    try {
      if (quid && sdai && addressQD) {
        const qdAmount = parseUnits("1", 18).toBigInt()

        quid.methods.qd_amt_to_sdai_amt(qdAmount, currentTimestamp)
          .call()
          .then(data => {
            setBigNumber(BigNumber.from(Number(formatUnits(data, 18)) * 100))

            if (bigNumber > 100) { setBigNumber(BigNumber.from(100)) } setPrice(String(bigNumber))
          })

        quid.methods.get_total_supply()
          .call()
          .then(totalSupply => {
            setTotalMinted(formatUnits(totalSupply, 18).split(".")[0])
          })

        sdai.methods.balanceOf(addressQD)
          .call()
          .then(data => {
            setTotalDeposited(formatUnits(data, 18))
          })
      }
    } catch (error) {
      console.error("Some problem with updateInfo, Summary.js, l.22: ", error)
    }
  }, [addressQD, bigNumber, sdai, quid])

  const getSales = useCallback(() => {
    try {
      if (quid && sdai && addressQD) {
        quid.methods.LENT()
          .call()
          .then(data => {
            console.log(data)
            setMintPeriodDays(String(Number(data) / SECONDS_IN_DAY))
          })

        quid.methods.sale_start()
          .call()
          .then(data => {
            setSmartContractStartTimestamp(data.toString())
          })
      }
    } catch (error) {
      console.error("Some problem with updateInfo, Summary.js, l.22: ", error)
    }
  }, [addressQD, sdai, quid])

  useEffect(() => {
    try{
      getSales()

      const timerId = setInterval(updateInfo, 5000)

      updateInfo()

      return () => clearInterval(timerId)
    }catch (error) {
      console.error("Some problem with sale's start function: ", error)
    }
  }, [getSales, updateInfo])

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
