//
//  SPIClient.h
//  SPIClient-iOS
//
//  Created by Yoo-Jin Lee on 2017-11-28.
//  Copyright © 2017 mx51. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SPIConnection.h"
#import "SPIModels.h"
#import "SPITransaction.h"
#import "SPISettlement.h"
#import "SPITenantsService.h"
#import "SPITransactionReportHelper.h"

@class SPIClient;
@class SPIPreAuth;
@class SPIPayAtTable;

typedef void (^SPICompletionTxResult)(SPIInitiateTxResult *result);
typedef void (^SPIAuthCodeSubmitCompletionResult)(SPISubmitAuthCodeResult *result);

/**
 Completion handler.
 
 @param alreadyMovedToIdleState True means we have moved back to the Idle state. false means current flow was not finished yet.
 @param state Current state.
 */
typedef void (^SPICompletionState)(BOOL alreadyMovedToIdleState, SPIState *state);

@protocol SPIDelegate <NSObject>

@optional

/**
 Subscribe to this event to know when the status changes.
 */
- (void)spi:(SPIClient *)spi statusChanged:(SPIState *)state;


/**
 Subscribe to this event to know when pairing flow changes.
 */
- (void)spi:(SPIClient *)spi pairingFlowStateChanged:(SPIState *)state;

/**
 When CurrentFlow==Transaction, this represents the state of the transaction process.
 */
- (void)spi:(SPIClient *)spi transactionFlowStateChanged:(SPIState *)state;

/**
 Subscribe to this event to know when the Secrets change, such as at the end
 of the pairing process, or everytime that the keys are periodicaly rolled.
 You then need to persist the secrets safely so you can instantiate SPI with
 them next time around.
 */
- (void)spi:(SPIClient *)spi secretsChanged:(SPISecrets *)secrets state:(SPIState *)state;

/**
 Subscribe to this event when you want to know if the address of the device have changed.
 */
- (void)spi:(SPIClient *)spi deviceAddressChanged:(SPIState *)state;

/**
 Subscribe to this event to know when the Printing response,
 */
- (void)printingResponse:(SPIMessage *)message;

/**
 Subscribe to this event to know when the Terminal Status response,
 */
- (void)terminalStatusResponse:(SPIMessage *)message;

/**
 Subscribe to this event to know when the Terminal Configuration response,
 */
- (void)terminalConfigurationResponse:(SPIMessage *)message;

/**
 Subscribe to this event to know when the Battery Level changed,
 */
- (void)batteryLevelChanged:(SPIMessage *)message;

/**
Subscribe to this event to receive update messages
*/
- (void)updateMessageReceived:(SPIMessage *)message;

@end

/**
 SPI integration client, used to manage connection to the terminal.
 */
@interface SPIClient : NSObject

/**
 The current state of the client.
 */
@property (nonatomic, readonly) SPIState *state;

/**
 The IP address of the target EFTPOS. Automatically prepends ws://
 Allows you to set the PIN pad address. Sometimes the PIN pad might change IP
 address (we recommend reserving static IPs if possible). Either way you need
 to allow your User to enter the IP address of the PIN pad.
 */
@property (nonatomic, copy) NSString *eftposAddress;

/**
 Uppercase AlphaNumeric string that Indentifies your POS instance. This value
 is displayed on the EFTPOS screen. Can only be called set in the Unpaired
 state.
 */
@property (nonatomic, copy) NSString *posId;

/**
 Uppercase AlphaNumeric string that Indentifies your POS instance. This value
 is displayed on the EFTPOS screen. Can only be called set in the Unpaired
 state.
 */
@property (nonatomic, copy) NSString *serialNumber;

/**
 Set the acquirer code of your bank, please contact mx51's Integration
 Engineers for acquirer code.
 */
@property (nonatomic, retain) NSString *acquirerCode;

/**
 Set the api key used for auto address discovery feature, please contact
 mx51's Integration Engineers for Api key.
 */
@property (nonatomic, retain) NSString *deviceApiKey;

@property (nonatomic, assign) BOOL autoAddressResolutionEnable;

@property (nonatomic, assign) BOOL testMode;

/**
 Vendor identifier of the POS itself. This value is used to identify the POS software
 to the EFTPOS terminal. Must be set before starting!
 */
@property (nonatomic, copy) NSString *posVendorId;

/**
 Version string of the POS itself. This value is used to identify the POS software
 to the EFTPOS terminal. Must be set before starting!
 */
@property (nonatomic, copy) NSString *posVersion;

@property (nonatomic, weak) id<SPIDelegate> delegate;

@property (nonatomic, readonly) SPIConfig *config;

@property (nonatomic, strong) SPITransactionReport *transactionReport;

@property (nonatomic, readonly) NSString *libraryLanguage;
/**
 If you provide secrets, it will start in PairedConnecting status; Otherwise
 it will start in Unpaired status.
 
 @return YES if needs to pair, else NO.
 */
- (BOOL)start;

/**
 * Returns the SDK version.
 */
+ (NSString *)getVersion;

/**
 Set the pairing secrets.
 
 @param encKey Encryption key.
 @param hmacKey HMAC key.
 */
- (void)setSecretEncKey:(NSString *)encKey hmacKey:(NSString *)hmacKey;

/**
 Call this one when a flow is finished and you want to go back to idle state.
 Typically when your user clicks the "OK" bubtton to acknowldge that pairing
 is finished, or that transaction is finished. When true, you can dismiss the
 flow screen and show back the idle screen.
 
 @param completion Completion handler.
 */
- (void)ackFlowEndedAndBackToIdle:(SPICompletionState)completion;

/**
 This will connect to the EFTPOS and start the pairing process.
 Only call this if you are in the Unpaired state.
 Subscribe to the PairingFlowStateChanged event to get updates on the pairing process.
 */
- (void)pair;

/**
 Call this when your user clicks yes to confirm the pairing code on your
 screen matches the one on the EFTPOS.
 */
- (void)pairingConfirmCode;

/**
 Call this if your user clicks CANCEL or NO during the pairing process.
 */
- (void)pairingCancel;

/**
 Call this when your uses clicks the Unpair button.
 This will disconnect from the EFTPOS and forget the secrets.
 The CurrentState is then changed to Unpaired.
 Call this only if you are not yet in the Unpaired state.
 */
- (BOOL)unpair;

/**
 Initiates a purchase transaction. Be subscribed to TxFlowStateChanged event
 to get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents NSInteger
 @param completion SPICompletionTxResult
 */
- (void)initiatePurchaseTx:(NSString *)posRefId
               amountCents:(NSInteger)amountCents
                completion:(SPICompletionTxResult)completion DEPRECATED_MSG_ATTRIBUTE("Use initiatePurchaseTx:purchaseAmount:tipAmount:cashoutAmount:promptForCash:completion instead.");

/**
 Initiates a purchase transaction. Be subscribed to TxFlowStateChanged event to
 get updates on the process.
 
 NOTE: Tip and cashout are not allowed simultaneously.
 
 @param posRefId The unique identifier for the transaction.
 @param purchaseAmount The purchase amount in cents.
 @param tipAmount The tip amount in cents.
 @param cashoutAmount The cashout amount in cents.
 @param promptForCashout Whether to prompt your customer for cashout on the EFTPOS.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */

- (void)initiatePurchaseTx:(NSString *)posRefId
            purchaseAmount:(NSInteger)purchaseAmount
                 tipAmount:(NSInteger)tipAmount
             cashoutAmount:(NSInteger)cashoutAmount
          promptForCashout:(BOOL)promptForCashout
                completion:(SPICompletionTxResult)completion;

/**
 Initiates a purchase transaction. Be subscribed to TxFlowStateChanged event to
 get updates on the process.
 
 NOTE: Tip and cashout are not allowed simultaneously.
 
 @param posRefId The unique identifier for the transaction.
 @param purchaseAmount The purchase amount in cents.
 @param tipAmount The tip amount in cents.
 @param cashoutAmount The cashout amount in cents.
 @param promptForCashout Whether to prompt your customer for cashout on the EFTPOS.
 @param options Additional options applied on per-transaction basis.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiatePurchaseTx:(NSString *)posRefId
            purchaseAmount:(NSInteger)purchaseAmount
                 tipAmount:(NSInteger)tipAmount
             cashoutAmount:(NSInteger)cashoutAmount
          promptForCashout:(BOOL)promptForCashout
                   options:(SPITransactionOptions *)options
                completion:(SPICompletionTxResult)completion;

/**
 Initiates a purchase transaction. Be subscribed to TxFlowStateChanged event to
 get updates on the process.
 
 NOTE: Tip and cashout are not allowed simultaneously.
 
 @param posRefId The unique identifier for the transaction.
 @param purchaseAmount The purchase amount in cents.
 @param tipAmount The tip amount in cents.
 @param cashoutAmount The cashout amount in cents.
 @param promptForCashout Whether to prompt your customer for cashout on the EFTPOS.
 @param options Additional options applied on per-transaction basis.
 @param surchargeAmount The surcharge amount in cents.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiatePurchaseTx:(NSString *)posRefId
            purchaseAmount:(NSInteger)purchaseAmount
                 tipAmount:(NSInteger)tipAmount
             cashoutAmount:(NSInteger)cashoutAmount
          promptForCashout:(BOOL)promptForCashout
                   options:(SPITransactionOptions *)options
           surchargeAmount:(NSInteger)surchargeAmount
                completion:(SPICompletionTxResult)completion;

/**
 Initiates a refund transaction. Be subscribed to TxFlowStateChanged event to
 get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The refund amount in cents.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateRefundTx:(NSString *)posRefId
             amountCents:(NSInteger)amountCents
              completion:(SPICompletionTxResult)completion;

/**
 Initiates a refund transaction. Be subscribed to TxFlowStateChanged event to
 get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The refund amount in cents.
 @param suppressMerchantPassword Ability to suppress Merchant Password from POS.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateRefundTx:(NSString *)posRefId
             amountCents:(NSInteger)amountCents
suppressMerchantPassword:(BOOL)suppressMerchantPassword
              completion:(SPICompletionTxResult)completion;

/**
 Initiates a refund transaction. Be subscribed to TxFlowStateChanged event to
 get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The refund amount in cents.
 @param suppressMerchantPassword Ability to suppress Merchant Password from POS.
 @param options Additional options applied on per-transaction basis.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateRefundTx:(NSString *)posRefId
             amountCents:(NSInteger)amountCents
suppressMerchantPassword:(BOOL)suppressMerchantPassword
                 options:(SPITransactionOptions *)options
              completion:(SPICompletionTxResult)completion;

/**
 Initiates a Mail Order / Telephone Order Purchase Transaction
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The purchase amount in cents.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateMotoPurchaseTx:(NSString *)posRefId
                   amountCents:(NSInteger)amountCents
                    completion:(SPICompletionTxResult)completion;

/**
 Initiates a Mail Order / Telephone Order Purchase Transaction
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The purchase amount in cents.
 @param surchargeAmount The surcharge amount in cents
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateMotoPurchaseTx:(NSString *)posRefId
                   amountCents:(NSInteger)amountCents
               surchargeAmount:(NSInteger)surchargeAmount
                    completion:(SPICompletionTxResult)completion;

/**
 Initiates a Mail Order / Telephone Order Purchase Transaction
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The purchase amount in cents.
 @param surchargeAmount The surcharge amount in cents
 @param suppressMerchantPassword Ability to suppress Merchant Password from POS.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateMotoPurchaseTx:(NSString *)posRefId
                   amountCents:(NSInteger)amountCents
               surchargeAmount:(NSInteger)surchargeAmount
      suppressMerchantPassword:(BOOL)suppressMerchantPassword
                    completion:(SPICompletionTxResult)completion;

/**
 Initiates a Mail Order / Telephone Order Purchase Transaction
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The purchase amount in cents.
 @param surchargeAmount The surcharge amount in cents
 @param suppressMerchantPassword Ability to suppress Merchant Password from POS.
 @param options Additional options applied on per-transaction basis.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateMotoPurchaseTx:(NSString *)posRefId
                   amountCents:(NSInteger)amountCents
               surchargeAmount:(NSInteger)surchargeAmount
      suppressMerchantPassword:(BOOL)suppressMerchantPassword
                       options:(SPITransactionOptions *)options
                    completion:(SPICompletionTxResult)completion;

/**
 Initiates a cashout only transaction. Be subscribed to TxFlowStateChanged
 event to get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The cashout amount in cents.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateCashoutOnlyTx:(NSString *)posRefId
                  amountCents:(NSInteger)amountCents
                   completion:(SPICompletionTxResult)completion;

/**
 Initiates a cashout only transaction. Be subscribed to TxFlowStateChanged
 event to get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The cashout amount in cents.
 @param surchargeAmount The surcharge amount in cents
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateCashoutOnlyTx:(NSString *)posRefId
                  amountCents:(NSInteger)amountCents
              surchargeAmount:(NSInteger)surchargeAmount
                   completion:(SPICompletionTxResult)completion;

/**
 Initiates a cashout only transaction. Be subscribed to TxFlowStateChanged
 event to get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param amountCents The cashout amount in cents.
 @param surchargeAmount The surcharge amount in cents
 @param options Additional options applied on per-transaction basis.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateCashoutOnlyTx:(NSString *)posRefId
                  amountCents:(NSInteger)amountCents
              surchargeAmount:(NSInteger)surchargeAmount
                      options:(SPITransactionOptions *)options
                   completion:(SPICompletionTxResult)completion;

/**
 Let the EFTPOS know whether merchant accepted or declined the signature.
 
 @param accepted YES if merchant accepted the signature from customer or NO otherwise.
 */
- (void)acceptSignature:(BOOL)accepted;

/**
 Submit the code obtained by your user when phoning for auth.
 It will return immediately to tell you whether the code has a valid format or
 not. If valid==true is returned, no need to do anything else. Expect updates
 via standard callback. If valid==false is returned, you can show your user
 the accompanying message, and invite them to enter another code.
 
 @param authCode The alphanumeric 6-character code obtained by your customer from the merchant call centre.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)submitAuthCode:(NSString *)authCode completion:(SPIAuthCodeSubmitCompletionResult)completion;

/**
 Attempts to cancel a transaction.
 Be subscribed to TxFlowStateChanged event to see how it goes.
 Wait for the transaction to be finished and then see whether cancellation was
 successful or not.
 */
- (void)cancelTransaction;

/**
 Initiates a settlement transaction.
 Be subscribed to TxFlowStateChanged event to get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateSettleTx:(NSString *)posRefId
              completion:(SPICompletionTxResult)completion;

/**
 Initiates a settlement transaction.
 Be subscribed to TxFlowStateChanged event to get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param options Additional options applied on per-transaction basis.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateSettleTx:(NSString *)posRefId
                 options:(SPITransactionOptions *)options
              completion:(SPICompletionTxResult)completion;

/**
 Initiates a settlement transaction.
 Be subscribed to TxFlowStateChanged event to get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateSettlementEnquiry:(NSString *)posRefId
                       completion:(SPICompletionTxResult)completion;

/**
 Initiates a settlement transaction.
 Be subscribed to TxFlowStateChanged event to get updates on the process.
 
 @param posRefId The unique identifier for the transaction.
 @param options Additional options applied on per-transaction basis.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateSettlementEnquiry:(NSString *)posRefId
                          options:(SPITransactionOptions *)options
                       completion:(SPICompletionTxResult)completion;

- (void)initiateGetTxWithPosRefID:(NSString *)posRefId
                      completion:(SPICompletionTxResult)completion;

/**
 Initiates a get last transaction operation.
 Use this when you want to retrieve the most recent transaction that was
 processed by the EFTPOS. Be subscribed to TxFlowStateChanged to get updates
 on the process.
 */
- (void)initiateGetLastTxWithCompletion:(SPICompletionTxResult)completion;

/**
 This is useful to recover from your POS crashing in the middle of a
 transaction. When you restart your POS, if you had saved enough state, you
 the posRefId that you passed in with the original transaction, and the
 transaction type. This method will return immediately whether recovery has
 started or not. If recovery has started, you need to bring up the transaction
 modal to your user a be listening to TxFlowStateChanged.
 
 @param posRefId The unique identifier for the transaction to be recovered.
 @param txType The transaction type.
 @param completion The completion block returning SPICompletionTxResult asynchronously.
 */
- (void)initiateRecovery:(NSString *)posRefId
         transactionType:(SPITransactionType)txType
              completion:(SPICompletionTxResult)completion;


- (void)initiateReversal:(NSString *)posRefId
              completion:(SPICompletionTxResult)completion;

/**
 Enables Pay-at-Table feature and returns the configuration object.
 
 @return Configuration object handling table and bill requests and responses.
 */
- (SPIPayAtTable *)enablePayAtTable;

/**
 Enables Preauth feature and returns the configuration object.
 
 @return Configuration object handling the dispatch queue.
 */
- (SPIPreAuth *)enablePreauth;

/**
 Printing Free Format Receipt
 
 @param key The authentication token
 @param payload The string of characters which represent the receipt that should be printed
 */
- (void)printReport:(NSString *)key
            payload:(NSString *)payload;

/**
 Get Terminal Status, Charging, Battery Level
 */
- (void)getTerminalStatus;

/**
 Get Terminal Configuration - Comms Selected, Merchant Id, PA Version, Payment Interface Version, Plugin Version, Serial Number, Terminal Id, Terminal Model
 */
- (void)getTerminalConfiguration;

/**
 * Static call to retrieve the available tenants (payment providers) for mx51. This is used to display the payment providers available in your Simple Payments Integration setup.
 * @param posVendorId Unique identifier for the POS vendor
 * @param apiKey Device API key that was provided by mx51 to identify the POS
 * @param countryCode An ISO 3166-1 alpha-2 country code. i.e for Australia - AU
 */
+ (void)getAvailableTenants:(NSString *)posVendorId
                     apiKey:(NSString *)apiKey
                countryCode:(NSString *)countryCode
                 completion:(SPITenantsResult)completion;

@end
