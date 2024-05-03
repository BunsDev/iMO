const ONE_DAY = 18 * 60 * 60 * 1 // 1 day in seconds
const START_PRICE = 54
const FINAL_PRICE = 99
const SALE_LENGTH = 46 * ONE_DAY

export const getQDPrice = saleStart => {
  console.log("getQDPrice: ", Date.now() / 1000, saleStart / 1000)
  const timeElapsed = Date.now() / 1000 - saleStart / 1000
  console.log("timeElapsed: ", timeElapsed)
  const priceDiff = FINAL_PRICE - START_PRICE
  const K = timeElapsed / SALE_LENGTH
  return K * priceDiff + START_PRICE
}
