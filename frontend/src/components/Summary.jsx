
import { useEffect, useState } from "react"
import { formatUnits, parseUnits } from "@ethersproject/units"
import { useSdaiContract, useQuidContract } from "../contexts/use-wallet"
import { numberWithCommas } from "../utils/number-with-commas"
import { address } from "../utils/constant"
import styles from "./Summary.module.scss"

const SECONDS_IN_DAY = 86400
const currentTimestamp = (Date.now() / 1000).toFixed(0)

export const Summary = () => {
  const contract = useQuidContract()
  const sdaiContract = useSdaiContract()
  const [
    smartContractStartTimestamp,
    setSmartContractStartTimestamp
  ] = useState("")
  const [mintPeriodDays, setMintPeriodDays] = useState("")
  const [totalDeposited, setTotalDeposited] = useState("")
  const [totalMinted, setTotalMinted] = useState("")
  const [price, setPrice] = useState("")

  useEffect(() => {
    contract?.LENT().then(data => {
      setMintPeriodDays(String(data.toNumber() / SECONDS_IN_DAY))
    })

    contract?.sale_start().then(data => {
      setSmartContractStartTimestamp(data.toString())
    })

    const updateInfo = () => {
      const qdAmount = parseUnits("1", 18)
      contract?.qd_amt_to_sdai_amt(qdAmount, currentTimestamp).then(data => {
        let n = Number(formatUnits(data, 18)) * 100 // TODO wtf
        if (n > 100) {
          n = 100
        }
        setPrice(String(n))
      })

      contract?.get_total_supply().then(totalSupply => {
        setTotalMinted(formatUnits(totalSupply, 18).split(".")[0])
      })

      sdaiContract
        ?.balanceOf(address)
        .then(data => {
          setTotalDeposited(formatUnits(data, 18))
        })
    }

    const timerId = setInterval(updateInfo, 5000)

    updateInfo()

    return () => clearInterval(timerId)
  }, [contract, sdaiContract])

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
        <div className={styles.title}>cNOTE Deposited</div>
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
