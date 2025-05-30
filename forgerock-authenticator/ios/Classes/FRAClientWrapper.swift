//
//  Copyright (c) 2022-2023 ForgeRock. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import FRAuthenticator

open class FRAClientWrapper {

    public static let shared = FRAClientWrapper()
    
    let storageClient = FRAStorageClient()
    let policyEvaluator = FRAPolicyEvaluator()
    
    //MARK: - Handle SDK methods
    
    func startSDK(result: FlutterResult?) {
        do {
            if(FRAClient.shared == nil) {
                try FRAClient.setStorage(storage: storageClient)
                try FRAClient.setPolicyEvaluator(policyEvaluator: policyEvaluator)
                FRAClient.start()
                NSLog("ForgeRock Authenticator SDK started")
            }
        }
        catch {
            if(result == nil) {
                NSLog(error.localizedDescription)
            } else {
                result?(FlutterError(code: "AUTHENTICATOR_EXCEPTION", message: error.localizedDescription, details: nil))
            }
        }
    }

    func createMechanismFromUri(uri: String, result: @escaping FlutterResult) {
        guard let url = URL(string: uri) else {
            result(FlutterError(code: "INVALID_QRCODE_EXCEPTION", message: "Invalid QR Code: QR Code data is not in URL format.", details: uri))
            return
        }

        FRAClient.shared?.createMechanismFromUri(uri: url, onSuccess: { (mechanism) in
            result(MechanismConverter.toJson(mechanism: mechanism))
        }, onError: { (error) in
            switch error {
            case MechanismError.alreadyExists(let mechanismId):
                result(FlutterError(code: "DUPLICATE_MECHANISM_EXCEPTION", message: error.localizedDescription, details: mechanismId))
                break
            case AccountError.failToRegisterPolicyViolation(let policy):
                result(FlutterError(code: "POLICY_VIOLATION_EXCEPTION", message: error.localizedDescription, details: policy))
                break
            default:
                result(FlutterError(code: "CREATE_MECHANISM_EXCEPTION", message: error.localizedDescription, details: nil))
                break
            }
        })
    }

    func getAllAccounts(result: @escaping FlutterResult) {
        if(FRAClient.shared == nil) {
            startSDK(result: result)
        }
        let accounts = FRAClient.shared?.getAllAccounts() ?? []
        var tmpAccounts: [Any] = []
        for account in accounts {
            if let convertedAccount = AccountConverter.toJson(account: account) {
                tmpAccounts.append(convertedAccount)
            }
        }

        result(tmpAccounts)
    }

    func updateAccount(json: String, result: @escaping FlutterResult) {
        do {
            if let account = try AccountConverter.fromJson(json: json) {
                let success = try FRAClient.shared?.updateAccount(account:account)
                result(success)
            }
        } catch AccountError.accountLocked(let param) {
            result(FlutterError(code: "ACCOUNT_LOCK_EXCEPTION", message: "This account is locked. It violates the following policy: (\(param))", details: nil))
        } catch {
            result(false);
        }
    }

    func removeAccount(identifier: String, result: @escaping FlutterResult) {
        guard let account = FRAClient.shared?.getAccount(identifier: identifier) else {
            result(FlutterError(code: "AUTHENTICATOR_EXCEPTION", message: "Could not retrieve the account with the identifier", details: nil))
            return
        }

        guard let success = FRAClient.shared?.removeAccount(account: account) else {
            result(FlutterError(code: "AUTHENTICATOR_EXCEPTION", message: "Could not remove the account with the identifier", details: nil))
            return
        }

        result(success)
    }

    func removeMechanism(identifier: String, result: @escaping FlutterResult) {
        guard let mechanism = storageClient.getMechanismForUUID(uuid: identifier) else {
            result(FlutterError(code: "AUTHENTICATOR_EXCEPTION", message: "Could not retrieve the mechanism with the identifier", details: nil))
            return
        }

        guard let success = FRAClient.shared?.removeMechanism(mechanism: mechanism) else {
            result(FlutterError(code: "AUTHENTICATOR_EXCEPTION", message: "Could not remove the mechanism with the identifier", details: nil))
            return
        }

        result(success)
    }

    func getOathTokenCode(identifier: String, result: @escaping FlutterResult) {
        guard let mechanism = storageClient.getMechanism(mechanismIdentifier: identifier) else {
            result(FlutterError(code: "AUTHENTICATOR_EXCEPTION", message: "Could not retrieve the account with the identifier", details: nil))
            return
        }

        if mechanism is TOTPMechanism, let totp = mechanism as? TOTPMechanism {
            if let oathTokenCode = try? totp.generateCode() {
                result(OathTokenCodeConverter.toJson(token: oathTokenCode))
            }
        } else if mechanism is HOTPMechanism, let hotp = mechanism as? HOTPMechanism {
            if let oathTokenCode = try? hotp.generateCode() {
                result(OathTokenCodeConverter.toJson(token: oathTokenCode))
            }
        }
    }

    func getAllNotificationsByAccountId(accountId: String, result: @escaping FlutterResult) {
        if let account = FRAClient.shared?.getAccount(identifier: accountId) {
            var pushMechanism : PushMechanism? = nil
            for m in account.mechanisms {
                if m.type == "push" {
                    pushMechanism = m as? PushMechanism
                }
            }

            if(pushMechanism != nil) {
                let notifications = FRAClient.shared?.getAllNotifications(mechanism: pushMechanism!) ?? []
                var tmpNotifications: [Any] = []
                for notification in notifications {
                    tmpNotifications.append(notification.toJson()!)
                }
                result(tmpNotifications)
            } else {
                result([])
            }
        }
    }

    func getAllNotifications(result: @escaping FlutterResult) {
        let notifications = FRAClient.shared?.getAllNotifications() ?? []
        var tmpNotifications: [Any] = []
        for notification in notifications {
            tmpNotifications.append(notification.toJson()!)
        }
        result(tmpNotifications)
    }

    func getAllMechanismsGroupByUID(result: @escaping FlutterResult) {
        var mechanismMap: [String: Any] = [:]
        if let mechanismList = storageClient.getAllMechanisms() {
            for mechanism in mechanismList {
                mechanismMap[mechanism.mechanismUUID] = MechanismConverter.toJson(mechanism: mechanism)
            }
        }
        result(mechanismMap)
    }


    func getNotification(notificationIdentifier: String, result: @escaping FlutterResult) {
        if let notification = FRAClient.shared?.getNotification(identifier: notificationIdentifier) {
            result(notification.toJson())
        } else {
            result(nil);
        }
    }

    func removeAllNotifications(result: @escaping FlutterResult) {
        result(storageClient.removeAllNotifications())
    }
    
    func getNotificationByMessageId(messageId: String) -> PushNotification? {
        NSLog("Looking for:  \(messageId)")
        let notificationList = FRAClient.shared?.getAllNotifications()
        for notification in notificationList! {
            let jsonDictionary = ConverterUtil.convertStringToDictionary(jsonString: notification.toJson()!)
            let mId = jsonDictionary?["messageId"] as! String
            if(mId == messageId) {
                NSLog("Message found.")
                return notification
            }
        }

        NSLog("Message not found.")
        return nil
    }

    @discardableResult func handleMessageWithPayload(userInfo: [AnyHashable : Any]) -> PushNotification? {
        if(FRAClient.shared == nil) {
            startSDK(result: nil)
        }

        let application = UIApplication.shared
        let aps = userInfo["aps"] as! [String: Any]
        let messageId = aps["messageId"] as! String


        var pushNotification : PushNotification? = self.getNotificationByMessageId(messageId: messageId)

        if(pushNotification == nil) {
            NSLog("Message not processed yet.")
            pushNotification = FRAPushHandler.shared.application(application, didReceiveRemoteNotification: userInfo)
            if(pushNotification != nil){
                NSLog("PushNotification successfuly created: \(String(describing: pushNotification?.toJson()))")
                self.updatePendingNotificationsCount()
                return pushNotification
            } else {
                NSLog("PushNotification could not be processed correctly.")
                return nil
            }
        } else {
            NSLog("Message already processed.")
            return pushNotification
        }
    }
    
    func handleMessageWithPayload(userInfo: [AnyHashable : Any], result: FlutterResult) {
        let pushNotification : PushNotification? = self.handleMessageWithPayload(userInfo: userInfo)

        if(pushNotification == nil) {
            result(nil)
        } else {
            result(pushNotification?.toJson())
        }
    }

    open func handleMessageFromWatch(userInfo: [AnyHashable : Any], approve: Bool, replyHandler: @escaping ([String : Any]) -> Void) {
        let pushNotification : PushNotification? = self.handleMessageWithPayload(userInfo: userInfo)
        
        if(approve) {
            pushNotification?.accept {
                replyHandler(["result": true])
            } onError: { (error) in
                replyHandler(["error": error.localizedDescription, "result": false])
            }
        } else {
            pushNotification?.deny {
                replyHandler(["result": true])
            } onError: { (error) in
                replyHandler(["error": error.localizedDescription, "result": false])
            }
        }

        self.updatePendingNotificationsCount()
    }
    
    func registerDeviceToken(deviceToken: Data) {
        if(FRAClient.shared == nil) {
            startSDK(result: nil)
        }

        let application = UIApplication.shared
        FRAPushHandler.shared.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func performPushAuthentication(notificationId: String, accept: Bool, result: FlutterResult?) {
        let pushNotification = FRAClient.shared?.getNotification(identifier: notificationId)

        if(accept) {
            pushNotification?.accept {
                if let result {
                    result(true)
                }
            } onError: { (error) in
                self.handlePushError(result: result, error: error)
            }
        } else {
            denyPushNotification(pushNotification: pushNotification, result: result)
        }

        self.updatePendingNotificationsCount()
    }

    func performPushAuthenticationWithChallenge(notificationId: String, challengeResponse: String, accept: Bool, result: FlutterResult?) {
        let pushNotification = FRAClient.shared?.getNotification(identifier: notificationId)

        if(accept) {
            pushNotification?.accept(
            challengeResponse: challengeResponse,
            onSuccess: {
                if let result {
                    result(true)
                }
            },
            onError: { (error) in
                self.handlePushError(result: result, error: error)
            })
        } else {
            denyPushNotification(pushNotification: pushNotification, result: result)
        }

        self.updatePendingNotificationsCount()
    }
    
    func performPushAuthenticationWithBiometric(notificationId: String, title: String, allowDeviceCredentials: Bool, accept: Bool, result: FlutterResult?) {
        let pushNotification = FRAClient.shared?.getNotification(identifier: notificationId)

        if(accept) {
            pushNotification?.accept(
            title: title,
            allowDeviceCredentials: allowDeviceCredentials,
            onSuccess: {
                if let result {
                    result(true)
                }
            },
            onError: { (error) in
                self.handlePushError(result: result, error: error)
            })
        } else {
            denyPushNotification(pushNotification: pushNotification, result: result)
        }

        self.updatePendingNotificationsCount()
    }

    private func denyPushNotification(pushNotification: PushNotification?, result: FlutterResult?) {
        pushNotification?.deny {
            if let result {
                result(true)
            }
        } onError: { (error) in
            self.handlePushError(result: result, error: error)
        }
    }
    
    private func handlePushError(result: FlutterResult?, error: Error) {
        if let result {
            if case AccountError.accountLocked(let param) = error {
                result(FlutterError(code: "ACCOUNT_LOCK_EXCEPTION", message: "This account is locked. It violates the following policy: (\(param))", details: nil))
            } else {
                result(FlutterError(code: "HANDLE_NOTIFICATION_EXCEPTION", message: error.localizedDescription, details: nil))
            }
        }
    }
    
    func getPendingNotificationsCount(result: @escaping FlutterResult) {
        result(pendingNotificationsCount())
    }
    
    func pendingNotificationsCount() -> Int {
        if(FRAClient.shared == nil) {
            startSDK(result: nil)
        }
        
        NSLog("Updating pending PushNotification count...")
        
        var count : Int = 0

        if let notificationList = FRAClient.shared?.getAllNotifications() {
            for notification in notificationList {
                if(notification.isPending && !notification.isExpired) {
                    count += 1
                } else {
                    return count
                }
            }
        }

        return count
    }
    
    open func updatePendingNotificationsCount() {
        UIApplication.shared.applicationIconBadgeNumber = pendingNotificationsCount()
    }

    func getLatestPendingNotification() -> PushNotification? {
        let notificationList = FRAClient.shared?.getAllNotifications()
        if let notification = notificationList?.first {
            if(notification.isPending && !notification.isExpired) {
                return notification
            }
        }

        return nil
    }
    

    //MARK: - Datastore upgrade

    func getStoredAccount(accountIdentifier: String, result: @escaping FlutterResult) {
        
        if let account = storageClient.getAccount(accountIdentifier: accountIdentifier) {
            let convertedAccount = AccountConverter.toJson(account: account)
            result(convertedAccount)
        } else {
            result(nil);
        }
    }
    
    func setStoredAccount(json: String, result: @escaping FlutterResult) {
        do {
            if let account = try AccountConverter.fromJson(json: json) {
                result(storageClient.setAccount(account:account))
            } else {
                result(false);
            }
        } catch {
            result(false);
        }
    }
    
    func getStoredMechanism(mechanismIdentifier: String, result: @escaping FlutterResult) {
        if let mechanism = storageClient.getMechanism(mechanismIdentifier: mechanismIdentifier) {
            let convertedMechanism = MechanismConverter.toJson(mechanism: mechanism)
            result(convertedMechanism)
        } else {
            result(nil);
        }
    }
    
    func setStoredMechanism(json: String, result: @escaping FlutterResult) {
        do {
            if let mechanism = try MechanismConverter.fromJson(json: json) {
                result(storageClient.setMechanism(mechanism:mechanism))
            } else {
                result(false);
            }
        } catch {
            result(false);
        }
    }
    
    func getStoredNotification(notificationIdentifier: String, result: @escaping FlutterResult) {
        if let notification = storageClient.getNotification(notificationIdentifier: notificationIdentifier) {
            result(notification.toJson)
        } else {
            result(nil);
        }
    }
    
    func setStoredNotification(json: String, result: @escaping FlutterResult) {
        do {
            if let notification = try PushNotificationConverter.fromJson(json: json) {
                result(storageClient.setNotification(notification: notification))
            } else {
                result(false);
            }
        } catch {
            result(false);
        }
    }

    func deleteStoredAccount(identifier: String, result: @escaping FlutterResult) {
        if let account = storageClient.getAccount(accountIdentifier: identifier) {
            result(storageClient.removeAccount(account: account))
        }
    }

    func removeAllData() {
        storageClient.removeAllData()
    }
    
    func getBackup(identifier: String, result: @escaping FlutterResult) {
        return result(storageClient.getBackup(identifier: identifier))
    }
    
    func setBackup(identifier: String, jsonData: String, result: @escaping FlutterResult) {
         return result(storageClient.setBackup(identifier: identifier, jsonData: jsonData))
    }
    
}
