/* 
 *  clsOOBEDefaults.swift
 *  
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

import Cocoa

private let kShouldNotFartInLieuOfBeep = "ShouldNotFartInLieuOfBeep"
private let kCheckUpdateAutomatically = "CheckUpdateAutomatically"
private let kCandidateListTextSize = "CandidateListTextSize"
private let kChooseCandidateUsingSpaceKey = "ChooseCandidateUsingSpaceKey"
private let kSelectPhraseAfterCursorAsCandidate = "SelectPhraseAfterCursorAsCandidate"
private let kUseHorizontalCandidateList = "UseHorizontalCandidateList"
private let kChineseConversionEnabledKey = "ChineseConversionEnabled"
private let kPhraseReplacementEnabledKey = "PhraseReplacementEnabled"

@objc public class OOBE : NSObject {

    @objc public static func setMissingDefaults () {
        // 既然 Preferences Module 的預設屬性不自動寫入 plist、而且還是 private，那這邊就先寫入了。

        // 首次啟用輸入法時設定不要自動更新，免得在某些要隔絕外部網路連線的保密機構內觸犯資安規則。
        if UserDefaults.standard.object(forKey: kCheckUpdateAutomatically) == nil {
            UserDefaults.standard.set(false, forKey: kCheckUpdateAutomatically)
            UserDefaults.standard.synchronize()
        }
        
        // 預設選字窗字詞文字尺寸，設成 18 剛剛好
        if UserDefaults.standard.object(forKey: kCandidateListTextSize) == nil {
            UserDefaults.standard.set(Preferences.candidateListTextSize, forKey: kCandidateListTextSize)
        }
        
        // 預設摁空格鍵來選字，所以設成 true
        if UserDefaults.standard.object(forKey: kChooseCandidateUsingSpaceKey) == nil {
            UserDefaults.standard.set(Preferences.chooseCandidateUsingSpace, forKey: kChooseCandidateUsingSpaceKey)
        }
        
        // 預設漢音風格選字，所以要設成 0
        if UserDefaults.standard.object(forKey: kSelectPhraseAfterCursorAsCandidate) == nil {
            UserDefaults.standard.set(Preferences.selectPhraseAfterCursorAsCandidate, forKey: kSelectPhraseAfterCursorAsCandidate)
        }
        
        // 預設橫向選字窗，不爽請自行改成縱向選字窗
        if UserDefaults.standard.object(forKey: kUseHorizontalCandidateList) == nil {
            UserDefaults.standard.set(Preferences.useHorizontalCandidateList, forKey: kUseHorizontalCandidateList)
        }
        
        // 預設停用繁體轉康熙模組
        if UserDefaults.standard.object(forKey: kChineseConversionEnabledKey) == nil {
            UserDefaults.standard.set(Preferences.chineseConversionEnabled, forKey: kChineseConversionEnabledKey)
        }
        
        // 預設停用自訂語彙置換
        if UserDefaults.standard.object(forKey: kPhraseReplacementEnabledKey) == nil {
            UserDefaults.standard.set(Preferences.phraseReplacementEnabled, forKey: kPhraseReplacementEnabledKey)
        }

        // 預設沒事不要在那裡放屁
        if UserDefaults.standard.object(forKey: kShouldNotFartInLieuOfBeep) == nil {
            UserDefaults.standard.set(Preferences.shouldNotFartInLieuOfBeep, forKey: kShouldNotFartInLieuOfBeep)
        }
        
        UserDefaults.standard.synchronize()
    }
}
