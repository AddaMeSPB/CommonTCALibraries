//
//  UserDefaults.swift
//  
//
//  Created by Saroar Khandoker on 06.12.2021.
//

import Foundation

public enum UserDefaultKey: String, CaseIterable {
    case isAuthorized,
         currentUser,
         token,
         cllocation,
         distance,
         isUserFirstNameEmpty,
         isAskPermissionCompleted,
         isFormFillUpCompleted

    case userName,
         isFristTimeLunch,
         isWelcomeScreensFillUp,
         startHour,
         endHour,

         wordBeginner,
         todayDayWordsBeginner,
         dayWordsBeginner,
       

         currentLanguage,
         learnLanguage,
         queryLanugae,
         wordLevel,

         wordIntermediate,
         wordAdvanced,
         dayWordsIntermediate,
         dayWordsAdvanced,
         deliveredNotificationWords,
         wordReminderCounters,
         repeatedMinutes,
         appleReceipt, purchaseDate,

         disableAllWordsStateListView

  case currentUserAppleVerifyReceiptKey = "com.word300.beginner_monthly.appleVerifyReceiptResponse"
}
