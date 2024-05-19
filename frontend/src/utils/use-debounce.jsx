import { useEffect } from "react"

export function useDebounce(value, handler, delay) {
  useEffect(() => {
    const timerId = setTimeout(() => {
      handler()
    }, delay)

    return () => {
      clearTimeout(timerId)
    }
  }, [value, handler, delay])
}
