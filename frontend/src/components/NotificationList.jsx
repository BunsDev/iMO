import React, { useContext } from "react"
import { Notification } from "./Notification"
import { NotificationContext } from "../contexts/NotificationProvider"

import styles from "./NotificationList.module.scss"

export const NotificationList = () => {
  const { notifications, close } = useContext(NotificationContext)

  return (
    <div className={styles.root}>
      {notifications.map(notification => (
        <Notification
          {...notification}
          key={notification.timestamp}
          className={styles.item}
          onClose={() => close(notification)}
        />
      ))}
    </div>
  )
}
