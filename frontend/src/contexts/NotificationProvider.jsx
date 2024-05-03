import React, { useCallback, useEffect, useMemo, useState } from "react"

export const NotificationContext = React.createContext({
  notifications: [],
  notify: notification => {
    throw new Error("Method not implemented.")
  },
  close: notification => {
    throw new Error("Method not implemented.")
  }
})

export const NotificationProvider = ({ autoHideDuration = 2500, children }) => {
  const [notifications, setNotifications] = useState([])

  const notify = useCallback(
    notification => {
      setNotifications(prevState => [
        {
          ...notification,
          timestamp: Date.now(),
          autoHideDuration: notification.autoHideDuration || autoHideDuration
        },
        ...prevState
      ])
    },
    [setNotifications, autoHideDuration]
  )

  const close = useCallback(
    notification => {
      setNotifications(prevState =>
        prevState.filter(item => item !== notification)
      )
    },
    [setNotifications]
  )

  const value = useMemo(() => ({ notifications, notify, close }), [
    close,
    notifications,
    notify
  ])

  useEffect(() => {
    const timerId = setInterval(() => {
      const currentTimestamp = Date.now()
      const filteredNotifications = notifications.filter(notification => {
        return (
          notification.autoHideDuration + notification.timestamp >
          currentTimestamp
        )
      })

      if (filteredNotifications.length !== notifications.length) {
        setNotifications(filteredNotifications)
      }
    }, 1000)

    return () => clearInterval(timerId)
  }, [notifications])

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  )
}
