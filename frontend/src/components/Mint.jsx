
import { useContext, useEffect, useState, useRef } from "react"
import { formatUnits, parseUnits } from "@ethersproject/units"
import { BigNumber } from "@ethersproject/bignumber"

import cn from "classnames"
import { Modal } from "./Modal"
import { Icon } from "./Icon"
import styles from "./Mint.module.scss"

import { useDebounce } from "../utils/use-debounce"
import { numberWithCommas } from "../utils/number-with-commas"

import { NotificationContext } from "../contexts/NotificationProvider"
import { useAppContext } from "../contexts/AppContext";

const DELAY = 60 * 60 * 8 // some buffer for allowance

export const Mint = () => {
  const { quid, sdai, addressQD, account } =
    useAppContext();

  const [mintValue, setMintValue] = useState("")
  const inputRef = useRef(null)
  const buttonRef = useRef(null)
  const { notify } = useContext(NotificationContext)
  
  const [sdaiValue, setSdaiValue] = useState(0)
  const [totalSupplyCap, setTotalSupplyCap] = useState(0)
  const [totalSupply, setTotalSupply] = useState("")
  const [state, setState] = useState("idle")
  const [isSameBeneficiary, setIsSameBeneficiary] = useState(true)
  const [beneficiary, setBeneficiary] = useState("")
  const [isModalOpen, setIsModalOpen] = useState(false)

  const handleCloseModal = () => {
    setIsModalOpen(false)
  }

  const handleAgreeTerms = async () => {
    setIsModalOpen(false)
    await localStorage.setItem("hasAgreedToTerms", "true")
    buttonRef?.current?.click()
  }

  const qdAmountToSdaiAmt = async (qdAmount, delay = 0) => {
    const currentTimestamp = (Date.now() / 1000 + delay).toFixed(0)
    return await quid.methods.qd_amt_to_sdai_amt(
      qdAmount instanceof BigNumber
        ? qdAmount
        : parseUnits(qdAmount.split(".")[0], 18),
      currentTimestamp
    ).call()
  }
  console.log({ mintValue, sdaiValue, totalSupplyCap, totalSupply });

  useDebounce(
    mintValue,
    async () => {
      if (parseInt(mintValue) > 0) {
        const result = await qdAmountToSdaiAmt(mintValue, 18)
        setSdaiValue(parseFloat(formatUnits(result, 18)))
      } else {
        setSdaiValue(0)
      }
    },
    500
  )

  useEffect(() => {
    const currentTimestamp = (Date.now() / 1000).toFixed(0)
    const updateTotalSupply = () => {
      Promise.all([
        quid.methods.get_total_supply_cap(currentTimestamp).call(),
        quid.methods.get_total_supply().call()
      ]).then(([totalSupplyCap, totalSupply]) => {
        const totalSupplyCapInt = parseInt(formatUnits(totalSupplyCap, 18))
        setTotalSupply(parseInt(formatUnits(totalSupply, 18)).toString())
        setTotalSupplyCap(totalSupplyCapInt)
      })
    }

    if (quid) {
      updateTotalSupply()
    }

    const timerId = setInterval(updateTotalSupply, 5000)

    return () => clearInterval(timerId)
  }, [quid, account])

  const handleChangeValue = e => {
    const regex = /^\d*(\.\d*)?$|^$/
    let originalValue = e.target.value

    if (
      originalValue.length > 1 &&
      originalValue[0] === "0" &&
      originalValue[1] !== "."
    ) {
      originalValue = originalValue.substring(1)
    }

    if (originalValue[0] === ".") {
      originalValue = "0" + originalValue
    }

    if (regex.test(originalValue)) {
      setMintValue(Number(originalValue).toFixed(0))
    }
  }

  const handleSetMaxValue = async () => {
    if (!account) {
      notify({
        message: "Please connect your wallet",
        severity: "error"
      })
      return
    }

    const costOfOneQd = Number(formatUnits(await qdAmountToSdaiAmt("1"), 18))
    const balance = Number(
      formatUnits(await sdai.methods.balanceOf(account).call(), 18)
    )
    const newValue =
      Number(totalSupplyCap) < balance ? totalSupplyCap : balance / costOfOneQd

    setMintValue(Number(newValue).toFixed(0))

    if (inputRef) {
      inputRef.current?.focus()
    }
  }

  const handleSubmit = async e => {
    e.preventDefault()
    const beneficiaryAccount =
      !isSameBeneficiary && beneficiary !== "" ? beneficiary : account

    const hasAgreedToTerms = (await localStorage.getItem("hasAgreedToTerms")) === "true"
    
    if (!hasAgreedToTerms) {
      setIsModalOpen(true)
      return
    }

    if (!isSameBeneficiary && beneficiary === "") {
      notify({
        severity: "error",
        message: "Please select a beneficiary"
      })
      return
    }

    if (!account) {
      notify({
        severity: "error",
        message: "Please connect your wallet"
      })
      return
    }

    if (!mintValue.length) {
      notify({
        severity: "error",
        message: "Please enter amount"
      })
      return
    }

    if (+mintValue < 50) {
      notify({
        severity: "error",
        message: "The amount should be more than 50"
      })
      return
    }

    if (+mintValue > totalSupplyCap) {
        notify({
            severity: "error",
            message: "The amount should be less than the maximum mintable QD"
        })
        return
    }

    const balance = Number(
        formatUnits(await sdai.method.balanceOf(account).call(), 18)
    )

    if (+sdaiValue > balance) {
        notify({
            severity: "error",
            message: "Cost shouldn't be more than your sDAI balance"
        })
        return
    }
    
    try {
      setState("loading")
      const qdAmount = parseUnits(mintValue, 18)
      var sdaiAmount = await qdAmountToSdaiAmt(qdAmount, DELAY)

      const allowanceBigNumber = await sdai.method.allowance(
        account, addressQD
      ).call()

      console.log(
        "Start minting:",
        "\nCurrent allowance: ",
        formatUnits(allowanceBigNumber, 18),
        "\nNote amount: ",
        formatUnits(sdaiAmount, 18)
      )

      // if (parseInt(formatUnits(allowanceBigNumber, 8)) !== 0) {
      if (parseInt(formatUnits(allowanceBigNumber, 18)) !== 0) {
        setState("decreaseAllowance")

        await sdai.methods.decreaseAllowance(
          addressQD, allowanceBigNumber
        ).call()
      }

      setState("approving")

      // const { hash } = 
      await sdai.method.approve(
        addressQD, sdaiAmount
      ).call()

      notify({
        severity: "success",
        message: "Please wait for approving",
        autoHideDuration: 4500
      })


      setState("minting")

      notify({
        severity: "success",
        message: "Please check your wallet"
      })

      const allowanceBeforeMinting = await sdai.methods.allowance(
        account, addressQD
      ).call()

      console.log(
        "Start minting:",
        "\nQD amount: ",
        mintValue,
        "\nCurrent account: ",
        account,
        "\nAllowance: ",
        formatUnits(allowanceBeforeMinting, 18)
      )

      await quid.methods.mint(qdAmount, beneficiaryAccount).call()

      notify({
        severity: "success",
        message: "Your minting is pending!"
      })

    } catch (err) {
      console.error(err)
      var msg
      let er = "MO::mint: supply cap exceeded"
      if (err.error?.message === er || err.message === er) {
        msg = "Please wait for more QD to become mintable..."
      } else {
        msg = err.error?.message || err.message
      }
      notify({
        severity: "error",
        message: msg,
        autoHideDuration: 3200
      })
    } finally {
      setState("none")
      setMintValue("")
    }
  }

  return (
    <form className={styles.root} onSubmit={handleSubmit}>
      <div>
        <div>
          <div className={styles.availability}>
            {/*<span className={styles.availabilityCurrent}>*/}
            {/*  Minted {numberWithCommas(totalSupply)} QD*/}
            {/*</span>*/}
            {/*<span className={styles.availabilityDivideSign}>/</span>*/}
            <span className={styles.availabilityMax}>
              <span style={{ color: "#02d802" }}>
                {numberWithCommas(totalSupplyCap.toFixed())}
                &nbsp;
              </span>
              QD mintable
            </span>
          </div>
          <div className={styles.inputContainer}>
            <input
              type="text"
              id="mint-input"
              className={styles.input}
              value={mintValue}
              onChange={handleChangeValue}
              placeholder="Mint amount"
              ref={inputRef}
            />
            <label htmlFor="mint-input" className={styles.dollarSign}>
              QD
            </label>
            <button
              className={styles.maxButton}
              onClick={handleSetMaxValue}
              type="button">
              Max
              <Icon
                preserveAspectRatio="none"
                className={styles.maxButtonBackground}
                name="btn-bg"
              />
            </button>
          </div>
          <div className={styles.sub}>
            <div className={styles.subLeft}>
              Cost in $
              <strong>
                {sdaiValue === 0
                  ? "sDAI Amount"
                  : numberWithCommas(sdaiValue.toFixed())}
              </strong>
            </div>
            {mintValue ? (
              <div className={styles.subRight}>
                <strong style={{ color: "#02d802" }}>
                  ${numberWithCommas((+mintValue - sdaiValue).toFixed())}
                </strong>
                Future profit
              </div>
            ) : null}
          </div>
          <button
            ref={buttonRef}
            type="submit"
            className={cn(styles.submit, styles[state])}
            disabled={state !== "none" || sdaiValue === 0}>
            {state !== "none" ? `...${state}` : "MINT"}
            <Icon
              preserveAspectRatio="none"
              className={styles.submitBtnL1}
              name="composite-btn-l1"
            />
            <Icon
              preserveAspectRatio="none"
              className={styles.submitBtnL2}
              name="composite-btn-l2"
            />
            <Icon
              preserveAspectRatio="none"
              className={styles.submitBtnL3}
              name="composite-btn-l3"
            />
            <div className={styles.glowEffect} />
          </button>
          <label style={{ position: "absolute", top: 165, right: -170 }}>
            <input
              name="isBeneficiary"
              className={styles.checkBox}
              type="checkbox"
              checked={isSameBeneficiary}
              onChange={evt => {
                setIsSameBeneficiary(!isSameBeneficiary)
              }}
            />
            <span className={styles.availabilityMax}>to myself</span>
          </label>
        </div>
      </div>
      {isSameBeneficiary ? null : (
        <div className={styles.beneficiaryContainer}>
          <div className={styles.inputContainer}>
            <input
              name="beneficiary"
              type="text"
              className={styles.beneficiaryInput}
              onChange={e => setBeneficiary(e.target.value)}
              placeholder={account ? String(account) : ""}
            />
            <label htmlFor="mint-input" className={styles.idSign}>
              beneficiary
            </label>
          </div>
        </div>
      )}
      <Modal
        open={isModalOpen}
        handleAgree={handleAgreeTerms}
        handleClose={handleCloseModal}
      />
    </form>
  )
}
