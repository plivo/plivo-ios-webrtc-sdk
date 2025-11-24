//
//  FeedbackManager.swift
//  PlivoVoiceKit
//
//  Created by Krishna Thakur on 05/05/21.
//

import Foundation

class FeedbackManager{

    private var statsBuffer = [String]()
    var webSocketClient:WebSocketClient?
    private var statsCounter = 0

    init() {
        webSocketClient = WebSocketClient()
        LogManager.shared.log("init FeedbackManager", level: .notice)
    }

    deinit {
        webSocketClient = nil
        LogManager.shared.log("deinit FeedbackManager", level: .notice)
    }

    func validateInputs(_ callUUID: String?, _ rating: Int, _ issues: [String], _ note: String?, _ sendConsoleLog: Bool) -> [String : Any] {
        var status: [String : Any] = [:]
        status["true"] = "No Error"

        if callUUID == nil || (callUUID?.count) == 0 {
            LogManager.shared.log("Caller UUID is mandatory", level: .debug)
            status["false"] = "Caller UUID is mandatory"
            return status
        }
        if (rating) <= 0 || (rating) > 5 {
            LogManager.shared.log("Star rating should be between 1 to 5", level: .debug)
            status["false"] = "Star rating should be between 1 to 5"
            return status
        }

        if rating > 0 && rating <= 5 {
            if note != nil && (note?.count ?? 0) > 0 && (note?.count ?? 0) > 280 {
                LogManager.shared.log("Note can be maximum 280 characters", level: .debug)
                status["false"] = "Comment note can be maximum 280 characters"
                return status
            }
            if rating != 5 && ((issues.count) == 0) {
                LogManager.shared.log("Atleast one issue is mandatory for feedback", level: .debug)
                status["false"] = "Atleast one issue is mandatory for feedback"
                return status
            }

            let defaultComments = Constant.DEFAULT_COMMENTS
            var issueFinal: [String] = []
            var issueFinalToBeSend: [String] = []

            if issues.count > 0 {
                //Map the existing issues and push to final list of issues enum (issue_final)
                for issue in issues {
                    let _issue = issue
                    if (defaultComments[_issue] != nil) {
                        let extractedIssue = defaultComments[_issue]
                        issueFinal.append(extractedIssue!)
                        issueFinalToBeSend.append(issue)
                    }
                }
                status["issues"] = issueFinalToBeSend
            }
            if issueFinalToBeSend.count == 0 {
                let validIssues = Array(defaultComments.keys)
                if rating == 5 {
                    LogManager.shared.log(" Feedback with full rating without any Issues or doesn't matche from predefined list of issues \(validIssues)", level: .debug)
                } else {
                    LogManager.shared.log(" Issues must be from the predefined list of issues for feedback \(validIssues)", level: .debug)
                    status["false"] = "Issues must be from the predefined list of issues for feedback"
                    return status
                }
            }
        }
        return status
    }

    func sendStats(statsDict:inout [String:Any], type:String){

        statsDict["callUUID"] = StatsConfig.call_uuid
        statsDict["corelationId"] = StatsConfig.call_uuid
        statsDict["callstats_key"] = StatsConfig.stats_key
        statsDict["userName"] = StatsConfig.username
        statsDict["msg"] = StatsConfig.msg
        statsDict["xcallUUID"] = StatsConfig.x_call_uuid

        //        LogManager.shared.log("sendStats() with json: \(statsDict)", level: .info)

        let statsJson = Utils.convertDict(toJSON: statsDict)
        if statsJson == "" {
            LogManager.shared.log("Stats cannot be sent to websocket: \(statsDict)", level: .error)
        } else {
            statsBuffer.append(statsJson)
            statsCounter += 1
            if ((type == Constant.CALL_STATS_MSG && (statsCounter == Constant.STATS_BUFFER_CAPACITY)) || (type  == Constant.CALL_ANSWERED_MSG) || (type  == Constant.CALL_SUMMARY_MSG)) {
                if (webSocketClient?.readyState == false) {
                    webSocketClient?.openWebSocket(messageArray: statsBuffer)
                } else {
                    webSocketClient?.sendMessageWebSocket(messageArray: &statsBuffer)
                }
                statsCounter = 0;
            }
        }
    }

    private func sendQualityFeedbackStats(_ issueWithoutDuplicates: [AnyHashable]?, _ xcallUUID: String?, _ val: NSNumber?, _ notes: String?) {
        var qualityFeedback = issueWithoutDuplicates?.map(\.description).joined(separator: ",")
        qualityFeedback = "\(qualityFeedback ?? "")\(" ")\(notes ?? "")"

        let info = [
            "overall" : "\(String(describing: val))",
            "comment" : qualityFeedback
        ]

        var feedbackData: [String : Any] = [:]

        if xcallUUID == StatsConfig.last_xcall_uuid{
            feedbackData["callUUID"] = StatsConfig.last_call_uuid
            feedbackData["callstats_key"] = StatsConfig.last_stats_key
            feedbackData["corelationId"] = StatsConfig.last_call_uuid
            feedbackData["xcallUUID"] = StatsConfig.last_xcall_uuid
        }else{
            feedbackData["callUUID"] = StatsConfig.call_uuid
            feedbackData["callstats_key"] = StatsConfig.stats_key
            feedbackData["corelationId"] = StatsConfig.call_uuid
            feedbackData["xcallUUID"] = StatsConfig.x_call_uuid
        }

        feedbackData["domain"] = Environment.sipDomain
        feedbackData["info"] = info
        feedbackData["msg"] = "FEEDBACK"
        feedbackData["source"] = Constant.STATS_SOURCE
        feedbackData["sdkVersion"] = Constant.PLIVO_ENDPOINT_VER
        feedbackData["timeStamp"] = "\(Utils.getCurrentTimeInMilliSeconds())"
        feedbackData["userName"] = StatsConfig.username
        feedbackData["version"] = Constant.STATS_VERSION

        let statsJson = Utils.convertDict(toJSON: feedbackData)
        statsBuffer.append(statsJson)
        if webSocketClient?.readyState == false {
            webSocketClient?.openWebSocket(messageArray: statsBuffer)
        } else {
            webSocketClient?.sendMessageWebSocket(messageArray: &statsBuffer)
        }
    }
}
